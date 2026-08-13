library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.Numeric_Std.all;

use work.livt_lang_icontext_package.t_icontext_in;

entity livt_ml_linear_int8broadcastmac64x8primitive is
	port(
		ctor_lvt_context_in : in t_icontext_in;
		ctor_request : in std_logic;
		ctor_clear : in std_logic;
		ctor_activation : in signed(31 downto 0);
		ctor_weights : in std_logic_vector(511 downto 0);
		ctor_resultindex : in std_logic_vector(5 downto 0);
		ctor_acknowledge : out std_logic;
		ctor_result : out signed(31 downto 0)
	);
end;

architecture RTL of livt_ml_linear_int8broadcastmac64x8primitive is
	type T_AccumulatorArray is array (0 to 63) of signed(31 downto 0);
	type T_ProductArray is array (0 to 7) of signed(31 downto 0);
	signal accumulators : T_AccumulatorArray := (others => (others => '0'));
	signal products : T_ProductArray := (others => (others => '0'));
	signal weight_row : std_logic_vector(511 downto 0) := (others => '0');
	signal activation_value : signed(15 downto 0) := (others => '0');
	signal pending_request : std_logic := '0';
	signal running : boolean := false;
	signal group_index : natural range 0 to 7 := 0;
begin
	compute : process(ctor_lvt_context_in.clk) is
		variable next_group : natural;
	begin
		if rising_edge(ctor_lvt_context_in.clk) then
			if ctor_lvt_context_in.rst = '1' then
				accumulators <= (others => (others => '0'));
				products <= (others => (others => '0'));
				weight_row <= (others => '0');
				activation_value <= (others => '0');
				pending_request <= '0';
				ctor_acknowledge <= '0';
				running <= false;
				group_index <= 0;
			elsif running then
				for lane in 0 to 7 loop
					accumulators(group_index * 8 + lane) <=
						accumulators(group_index * 8 + lane) + products(lane);
				end loop;
				if group_index = 7 then
					ctor_acknowledge <= pending_request;
					running <= false;
				else
					next_group := group_index + 1;
					for lane in 0 to 7 loop
						products(lane) <= resize(
							activation_value * signed(weight_row((next_group * 8 + lane) * 8 + 7 downto
								(next_group * 8 + lane) * 8)), 32);
					end loop;
					group_index <= next_group;
				end if;
			elsif ctor_request /= ctor_acknowledge then
				if ctor_clear = '1' then
					accumulators <= (others => (others => '0'));
					ctor_acknowledge <= ctor_request;
				else
					weight_row <= ctor_weights;
					activation_value <= resize(ctor_activation, 16);
					pending_request <= ctor_request;
					group_index <= 0;
					for lane in 0 to 7 loop
						products(lane) <= resize(
							resize(ctor_activation, 16) *
							signed(ctor_weights(lane * 8 + 7 downto lane * 8)), 32);
					end loop;
					running <= true;
				end if;
			end if;
		end if;
	end process compute;

	read_result : process(all) is
	begin
		if is_x(ctor_resultindex) then
			ctor_result <= (others => '0');
		else
			ctor_result <= accumulators(to_integer(unsigned(ctor_resultindex)));
		end if;
	end process read_result;
end;
