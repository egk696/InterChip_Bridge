----------------------------------------------------------------------------------
-- Created By: Eleftherios Kyriakakis
-- 
-- Design Name: InterChip NoC Communication Bridge for FPGAs
-- Module Name: grey_converter - Behavioral
-- Project Name: SEUD-MIST KTH Royal Institute Of Technology
-- Tested Devices:
-- 	FPGA: Artix-7, SmartFusion2
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity grey_converter is
    generic(
        DATA_WIDTH : integer := 8
    );
    port( 
    	sel: in std_logic ;-- for selecting whether to convert binary to gray or vice versa
    	data : in  STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0);
    	data_out : inout  STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0)
    );
end grey_converter;

architecture Behavioral of grey_converter is
begin
	process(sel,data,data_out)
	begin
		if (sel='1') then -- converting binary to gray
		    data_out(DATA_WIDTH-1) <=data(DATA_WIDTH-1);
		    for i in DATA_WIDTH-2 downto 0 loop
                data_out(i) <=data(i+1) xor data (i);
            end loop;
		else -- converting gray to binary
		    data_out(DATA_WIDTH-1) <=data(DATA_WIDTH-1);
            for i in DATA_WIDTH-2 downto 0 loop
                data_out(i) <=data(i) xor data_out (i+1);
            end loop;
		end if ;
	end process;
end Behavioral;
