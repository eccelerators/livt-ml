library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.Numeric_Std.all;

use work.livt_lang_icontext_package.t_icontext_in;

entity livt_ml_linear_int8dot64x8primitive is
	port(
		ctor_lvt_context_in : in t_icontext_in;
		ctor_request : in std_logic;
		ctor_clear : in std_logic;
		ctor_configure : in std_logic;
		ctor_index : in std_logic_vector(5 downto 0);
		ctor_value : in signed(31 downto 0);
		ctor_weights : in std_logic_vector(511 downto 0);
		ctor_acknowledge : out std_logic;
		ctor_result : out signed(31 downto 0)
	);
end;

architecture RTL of livt_ml_linear_int8dot64x8primitive is
	type T_ActivationArray is array (0 to 63) of signed(15 downto 0);
	type T_ProductArray is array (0 to 7) of signed(31 downto 0);
	signal activations : T_ActivationArray := (others => (others => '0'));
	signal products : T_ProductArray := (others => (others => '0'));
	signal weight_row : std_logic_vector(511 downto 0) := (others => '0');
	signal accumulator : signed(31 downto 0) := (others => '0');
	signal pending_request : std_logic := '0';
	signal running : boolean := false;
	signal group_index : natural range 0 to 7 := 0;
begin
	compute : process(ctor_lvt_context_in.clk) is
		variable activation_index : natural;
		variable next_group : natural;
		variable pair0, pair1, pair2, pair3 : signed(31 downto 0);
		variable half0, half1 : signed(31 downto 0);
		variable group_sum, next_accumulator : signed(31 downto 0);
	begin
		if rising_edge(ctor_lvt_context_in.clk) then
			if ctor_lvt_context_in.rst = '1' then
				activations <= (others => (others => '0'));
				products <= (others => (others => '0'));
				weight_row <= (others => '0');
				accumulator <= (others => '0');
				pending_request <= '0';
				ctor_acknowledge <= '0';
				ctor_result <= (others => '0');
				running <= false;
				group_index <= 0;
			elsif running then
				pair0 := products(0) + products(1);
				pair1 := products(2) + products(3);
				pair2 := products(4) + products(5);
				pair3 := products(6) + products(7);
				half0 := pair0 + pair1;
				half1 := pair2 + pair3;
				group_sum := half0 + half1;
				next_accumulator := accumulator + group_sum;
				accumulator <= next_accumulator;
				if group_index = 7 then
					ctor_result <= next_accumulator;
					ctor_acknowledge <= pending_request;
					running <= false;
				else
					next_group := group_index + 1;
					for lane in 0 to 7 loop
						products(lane) <= resize(
							activations(next_group * 8 + lane) *
							signed(weight_row((next_group * 8 + lane) * 8 + 7 downto
								(next_group * 8 + lane) * 8)), 32);
					end loop;
					group_index <= next_group;
				end if;
			elsif ctor_request /= ctor_acknowledge then
				if ctor_clear = '1' then
					accumulator <= (others => '0');
					ctor_result <= (others => '0');
					ctor_acknowledge <= ctor_request;
				elsif ctor_configure = '1' then
					if not is_x(ctor_index) then
						activation_index := to_integer(unsigned(ctor_index));
						activations(activation_index) <= resize(ctor_value, 16);
					end if;
					ctor_acknowledge <= ctor_request;
				else
					weight_row <= ctor_weights;
					accumulator <= (others => '0');
					pending_request <= ctor_request;
					group_index <= 0;
					for lane in 0 to 7 loop
						products(lane) <= resize(
							activations(lane) * signed(ctor_weights(lane * 8 + 7 downto lane * 8)), 32);
					end loop;
					running <= true;
				end if;
			end if;
		end if;
	end process compute;
end;
