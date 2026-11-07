library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.livt_lang_icontext_package.all;

entity livt_ml_linear_int8matrixaccumulator32primitive is
    port (
        ctor_lvt_context_in : in t_icontext_in;
        ctor_activationbits, ctor_productstages : in signed(31 downto 0);
        ctor_request : in std_logic;
        ctor_operation, ctor_index : in signed(31 downto 0);
        ctor_values : in std_logic_vector(511 downto 0);
        ctor_seed : in std_logic_vector(63 downto 0);
        ctor_acknowledge : out std_logic;
        ctor_result : out std_logic_vector(64 downto 0);
        ctor_busy : out std_logic;
        ctor_count : in signed(31 downto 0) := (others => '0');
        ctor_rowValid : in std_logic := '0';
        ctor_streamError : in std_logic := '0';
        ctor_rowReady : out std_logic;
        ctor_streamFailed : out std_logic
    );
end;

architecture rtl of livt_ml_linear_int8matrixaccumulator32primitive is
    constant ERROR_RESULT : std_logic_vector(64 downto 0) := (64 => '1', others => '0');
    type phase_t is (idle, clearing, computing, adding, read_wait, reading, finishing);
    type activations_t is array (0 to 63) of signed(31 downto 0);
    type operands_t is array (0 to 7) of signed(31 downto 0);
    type weights_t is array (0 to 7) of signed(7 downto 0);
    type products_t is array (0 to 7) of signed(39 downto 0);
    type low_products_t is array (0 to 7) of signed(24 downto 0);
    type high_products_t is array (0 to 7) of signed(23 downto 0);
    type pairs_t is array (0 to 3) of signed(40 downto 0);
    type halves_t is array (0 to 1) of signed(41 downto 0);
    type sums_t is array (0 to 1023) of signed(63 downto 0);
    signal phase : phase_t := idle;
    signal activations : activations_t;
    signal loaded : std_logic_vector(3 downto 0) := "0000";
    signal operands : operands_t;
    signal weights : weights_t;
    signal products : products_t;
    signal low_products : low_products_t;
    signal high_products : high_products_t;
    signal pairs : pairs_t;
    signal halves : halves_t;
    signal group_sum : signed(42 downto 0);
    -- Every full signed 32x8, 64-element dot product fits in 46 bits.
    signal dot_sum : signed(45 downto 0);
    signal valid, last : std_logic_vector(5 downto 0) := (others => '0');
    signal next_group : natural range 1 to 8 := 1;
    signal active_rows : natural range 0 to 1024 := 0;
    signal cursor : natural range 0 to 1023 := 0;
    signal poisoned : boolean := false;
    signal pending : std_logic := '0';
    signal sums : sums_t;
    attribute ram_style : string;
    attribute ram_style of sums : signal is "block";
    signal read_address, write_address : natural range 0 to 1023 := 0;
    signal read_value, write_value : signed(63 downto 0);
    signal write_enable : boolean := false;

    -- Streaming rows are consumed in order. The producer retains the live row
    -- until ready: no second 512-bit weight register or payload reset is needed.
    signal streaming : boolean := false;
    signal feed_group : natural range 0 to 7 := 0;
    signal rows_to_feed : natural range 0 to 1024 := 0;
    signal end_row : natural range 1 to 1024 := 1;
    signal first : std_logic_vector(5 downto 0) := (others => '0');
    signal commit_pending : boolean := false;
    signal commit_dot : signed(45 downto 0);

    function fits(value : signed(31 downto 0); bits : integer) return boolean is
    begin
        if bits < 2 or bits > 32 then return false; end if;
        for i in 31 downto 0 loop
            if i >= bits - 1 and value(i) /= value(31) then return false; end if;
        end loop;
        return true;
    end;
begin
    ctor_busy <= '0' when phase = idle else '1';
    ctor_rowReady <= '1' when phase = computing and streaming and
        rows_to_feed /= 0 and feed_group = 7 and ctor_rowValid = '1'
        and ctor_streamError = '0' and not poisoned and ctor_lvt_context_in.rst = '0' else '0';
    ctor_streamFailed <= '1' when poisoned else '0';

    -- Payload RAM has no reset: Begin explicitly initializes accessible rows.
    -- Finish acknowledges only after the last registered write has committed.
    process(ctor_lvt_context_in.clk)
    begin
        if rising_edge(ctor_lvt_context_in.clk) then
            if ctor_lvt_context_in.rst = '0' then
                if write_enable then sums(write_address) <= write_value; end if;
                read_value <= sums(read_address);
            end if;
        end if;
    end process;

    process(ctor_lvt_context_in.clk)
        variable op, idx, bits, stages : integer;
        variable selected : natural range 1 to 2;
        variable lane_value : signed(31 downto 0);
        variable bad_load : boolean;
        variable joined : signed(39 downto 0);
        variable total : signed(64 downto 0);
    begin
        if rising_edge(ctor_lvt_context_in.clk) then
            write_enable <= false;
            commit_pending <= false;
            if ctor_lvt_context_in.rst = '1' then
                phase <= idle;
                loaded <= "0000";
                active_rows <= 0;
                poisoned <= false;
                pending <= '0';
                valid <= (others => '0');
                last <= (others => '0');
                first <= (others => '0');
                streaming <= false;
                feed_group <= 0;
                rows_to_feed <= 0;
                end_row <= 1;
                ctor_acknowledge <= '0';
                ctor_result <= (others => '0');
            else
                bits := to_integer(ctor_activationbits);
                stages := to_integer(ctor_productstages);
                selected := 1;
                if stages = 2 then selected := 2; end if;
                case phase is
                    when idle =>
                        if ctor_request /= ctor_acknowledge then
                            op := to_integer(ctor_operation);
                            idx := to_integer(ctor_index);
                            pending <= ctor_request;
                            streaming <= false;
                            if bits < 2 or bits > 32 or (stages /= 1 and stages /= 2) then
                                active_rows <= 0;
                                loaded <= "0000";
                                ctor_result <= ERROR_RESULT;
                                ctor_acknowledge <= ctor_request;
                            elsif op = 0 then
                                loaded <= "0000";
                                active_rows <= 0;
                                poisoned <= false;
                                if idx < 1 or idx > 1024 then
                                    ctor_result <= ERROR_RESULT;
                                    ctor_acknowledge <= ctor_request;
                                else
                                    active_rows <= idx;
                                    cursor <= 0;
                                    phase <= clearing;
                                end if;
                            elsif op = 1 then
                                if idx < 0 or idx > 3 or active_rows = 0 or poisoned then
                                    loaded <= "0000";
                                    ctor_result <= ERROR_RESULT;
                                else
                                    bad_load := false;
                                    for lane in 0 to 15 loop
                                        lane_value := signed(ctor_values(lane*32+31 downto lane*32));
                                        activations(idx*16+lane) <= lane_value;
                                        if not fits(lane_value, bits) then bad_load := true; end if;
                                    end loop;
                                    loaded(idx) <= '0';
                                    ctor_result <= ERROR_RESULT;
                                    if not bad_load then
                                        loaded(idx) <= '1';
                                        ctor_result <= (others => '0');
                                    end if;
                                end if;
                                ctor_acknowledge <= ctor_request;
                            elsif active_rows = 0 or poisoned or idx < 0 or idx >= active_rows then
                                if op = 2 or op = 4 or op = 5 then poisoned <= true; end if;
                                ctor_result <= ERROR_RESULT;
                                ctor_acknowledge <= ctor_request;
                            elsif op = 5 then
                                if loaded /= "1111" or ctor_count <= 0 or
                                    ctor_count > to_signed(active_rows - idx, 32) then
                                    poisoned <= true;
                                    ctor_result <= ERROR_RESULT;
                                    ctor_acknowledge <= ctor_request;
                                else
                                    streaming <= true;
                                    rows_to_feed <= to_integer(ctor_count);
                                    end_row <= idx + to_integer(ctor_count);
                                    cursor <= idx;
                                    feed_group <= 0;
                                    first <= (others => '0');
                                    valid <= (others => '0');
                                    last <= (others => '0');
                                    dot_sum <= (others => '0');
                                    ctor_result <= (others => '0');
                                    phase <= computing;
                                end if;
                            elsif op = 2 then
                                if loaded /= "1111" then
                                    poisoned <= true;
                                    ctor_result <= ERROR_RESULT;
                                    ctor_acknowledge <= ctor_request;
                                else
                                    read_address <= idx;
                                    write_address <= idx;
                                    next_group <= 1;
                                    valid <= "000001";
                                    last <= "000000";
                                    dot_sum <= (others => '0');
                                    for lane in 0 to 7 loop
                                        operands(lane) <= activations(lane);
                                        weights(lane) <= signed(ctor_values(lane*8+7 downto lane*8));
                                    end loop;
                                    phase <= computing;
                                end if;
                            elsif op = 3 then
                                read_address <= idx;
                                phase <= read_wait;
                            elsif op = 4 then
                                write_address <= idx;
                                write_value <= signed(ctor_seed);
                                write_enable <= true;
                                ctor_result <= (others => '0');
                                phase <= finishing;
                            else
                                ctor_result <= ERROR_RESULT;
                                ctor_acknowledge <= ctor_request;
                            end if;
                        end if;
                    when clearing =>
                        write_address <= cursor;
                        write_value <= (others => '0');
                        write_enable <= true;
                        if cursor = active_rows - 1 then
                            ctor_result <= (others => '0');
                            phase <= finishing;
                        else
                            cursor <= cursor + 1;
                        end if;
                    when computing =>
                        valid <= valid(4 downto 0) & '0';
                        last <= last(4 downto 0) & '0';
                        first <= first(4 downto 0) & '0';
                        if valid(0) = '1' then
                            for lane in 0 to 7 loop
                                if stages = 1 then
                                    products(lane) <= operands(lane) * weights(lane);
                                else
                                    low_products(lane) <= signed('0' & std_logic_vector(operands(lane)(15 downto 0))) * weights(lane);
                                    high_products(lane) <= operands(lane)(31 downto 16) * weights(lane);
                                end if;
                            end loop;
                        end if;
                        if stages = 2 and valid(1) = '1' then
                            for lane in 0 to 7 loop
                                joined := shift_left(resize(high_products(lane), 40), 16) + resize(low_products(lane), 40);
                                products(lane) <= joined;
                            end loop;
                        end if;
                        if valid(selected) = '1' then
                            for lane in 0 to 3 loop
                                pairs(lane) <= resize(products(2*lane), 41) + resize(products(2*lane+1), 41);
                            end loop;
                        end if;
                        if valid(selected+1) = '1' then
                            for lane in 0 to 1 loop
                                halves(lane) <= resize(pairs(2*lane), 42) + resize(pairs(2*lane+1), 42);
                            end loop;
                        end if;
                        if valid(selected+2) = '1' then
                            group_sum <= resize(halves(0), 43) + resize(halves(1), 43);
                            if streaming and last(selected+2) = '1' then
                                read_address <= cursor;
                            end if;
                        end if;
                        if valid(selected+3) = '1' then
                            if streaming and first(selected+3) = '1' then
                                dot_sum <= resize(group_sum, 46);
                            else
                                dot_sum <= dot_sum + resize(group_sum, 46);
                            end if;
                            if last(selected+3) = '1' then
                                if streaming then
                                    commit_dot <= dot_sum + resize(group_sum, 46);
                                    commit_pending <= true;
                                else
                                    phase <= adding;
                                end if;
                            end if;
                        end if;
                        if streaming then
                            if rows_to_feed /= 0 and ctor_rowValid = '1' then
                                for lane in 0 to 7 loop
                                    operands(lane) <= activations(feed_group*8+lane);
                                    weights(lane) <= signed(ctor_values((feed_group*8+lane)*8+7 downto (feed_group*8+lane)*8));
                                end loop;
                                valid(0) <= '1';
                                if feed_group = 0 then first(0) <= '1'; end if;
                                if feed_group = 7 then
                                    last(0) <= '1';
                                    feed_group <= 0;
                                    rows_to_feed <= rows_to_feed - 1;
                                else
                                    feed_group <= feed_group + 1;
                                end if;
                            end if;
                            if commit_pending then
                                total := resize(read_value, 65) + resize(commit_dot, 65);
                                if total(64) /= total(63) then
                                    poisoned <= true;
                                    ctor_result <= ERROR_RESULT;
                                    valid <= (others => '0');
                                    phase <= finishing;
                                else
                                    write_address <= cursor;
                                    write_value <= total(63 downto 0);
                                    write_enable <= true;
                                    if cursor = end_row - 1 then
                                        phase <= finishing;
                                    else
                                        cursor <= cursor + 1;
                                    end if;
                                end if;
                            end if;
                            -- Cancellation is sticky and takes precedence over writeback.
                            -- Dropping valid mid-row violates the retained-row contract.
                            if ctor_streamError = '1' or
                                (feed_group /= 0 and ctor_rowValid /= '1') then
                                poisoned <= true;
                                ctor_result <= ERROR_RESULT;
                                write_enable <= false;
                                valid <= (others => '0');
                                commit_pending <= false;
                                phase <= finishing;
                            end if;
                        elsif next_group < 8 then
                            for lane in 0 to 7 loop
                                operands(lane) <= activations(next_group*8+lane);
                                weights(lane) <= signed(ctor_values((next_group*8+lane)*8+7 downto (next_group*8+lane)*8));
                            end loop;
                            valid(0) <= '1';
                            if next_group = 7 then last(0) <= '1'; end if;
                            next_group <= next_group + 1;
                        end if;
                    when adding =>
                        total := resize(read_value, 65) + resize(dot_sum, 65);
                        ctor_result <= (others => '0');
                        if total(64) /= total(63) then
                            poisoned <= true;
                            ctor_result <= ERROR_RESULT;
                        else
                            write_value <= total(63 downto 0);
                            write_enable <= true;
                        end if;
                        phase <= finishing;
                    when read_wait =>
                        phase <= reading;
                    when reading =>
                        ctor_result <= '0' & std_logic_vector(read_value);
                        ctor_acknowledge <= pending;
                        phase <= idle;
                    when finishing =>
                        ctor_acknowledge <= pending;
                        phase <= idle;
                end case;
            end if;
        end if;
    end process;
end;
