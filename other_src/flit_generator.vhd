library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity flit_generator is 
	generic(
		DATA_WIDTH : Integer := 8;
		RATE_WIDTH : Integer := 14
	);
	port(
		clk_i : in std_logic;
        rstn_i : in std_logic;
		en : in std_logic;
		load_o : out std_logic;
		flit_o : out std_logic_vector(DATA_WIDTH-1 downto 0)
	);
end flit_generator;

architecture behave of flit_generator is

	signal load_en : std_logic := '0';
	signal flit_data : unsigned(DATA_WIDTH-1 downto 0) := (others=>'0');

begin

inject_data: process(clk_i, flit_data)
	variable load_countdown : unsigned(RATE_WIDTH-1 downto 0) := (others=>'1');
begin
    if rstn_i = '0' then
        load_en <= '0';
        load_countdown := (others=>'1');
        flit_data <= (others=>'0');
	elsif rising_edge(clk_i) then
        if en = '1' then
            if load_countdown = 0 then
                load_en <= '1';
                flit_data <= flit_data + 1;
            else
                load_en <= '0';
            end if;
            load_countdown := load_countdown - 1;
        end if;
	end if;
end process;

flit_o <= std_logic_vector(flit_data);
load_o <= load_en;

end behave;