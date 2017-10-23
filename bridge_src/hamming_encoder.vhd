----------------------------------------------------------------------------------
-- Created By: Eleftherios Kyriakakis
-- 
-- Design Name: InterChip NoC Communication Bridge for FPGAs
-- Module Name: hamming_encoder - behave_parallel
-- Project Name: SEUD-MIST KTH Royal Institute Of Technology
-- Tested Devices:
-- 	FPGA: Artix-7, SmartFusion2
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.all;
use work.utils_pack.all;

entity hamming_encoder is
    generic(
        DATA_WIDTH : Integer := 8;
        PARITY_BITS : Integer := 3;
        EN_DED : Integer := 1
    );
    port (
        clk_i : in std_logic := '0';
        en_i : in std_logic := '0';
        data_i : in std_logic_vector(DATA_WIDTH-1 downto 0);
        data_o : out std_logic_vector(DATA_WIDTH+PARITY_BITS-1 downto 0);
        done_o : out std_logic := '0'
    );
end hamming_encoder; 

architecture behave_parallel of hamming_encoder is
    signal hamm_encoded_data : std_logic_vector(DATA_WIDTH+PARITY_BITS-1 downto 0);
    signal encode_complete : std_logic := '0';
begin

hamm_encode: process(clk_i, data_i, en_i)
begin
	if rising_edge(clk_i) then
		if en_i = '1' then
			hamm_encoded_data <= hamming_encode(data_i, DATA_WIDTH, PARITY_BITS-EN_DED, EN_DED);
			encode_complete <= '1';
		end if;
		if encode_complete = '1' then
			encode_complete <= '0';
		end if;
	end if;
end process;

data_o <= hamm_encoded_data;
done_o <= encode_complete;

end behave_parallel;
