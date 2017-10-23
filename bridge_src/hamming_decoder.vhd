----------------------------------------------------------------------------------
-- Created By: Eleftherios Kyriakakis
-- 
-- Design Name: InterChip NoC Communication Bridge for FPGAs
-- Module Name: hamming_decoder - behave_parallel
-- Project Name: SEUD-MIST KTH Royal Institute Of Technology
-- Tested Devices:
-- 	FPGA: Artix-7, SmartFusion2
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.all;
use work.utils_pack.all;

entity hamming_decoder is
    generic(
        DATA_WIDTH : Integer := 8;
        PARITY_BITS : Integer := 3;
        EN_DED : Integer := 1
    );
    port (
        clk_i : in std_logic := '0';
        rstn_i : in std_logic := '1';
        en_i : in std_logic := '0';
        data_i : in std_logic_vector(DATA_WIDTH+PARITY_BITS-1 downto 0);
        data_o : out std_logic_vector(DATA_WIDTH-1 downto 0);
        done_o : out std_logic := '0';
        ne_o : out std_logic := '0';
        sec_o : out std_logic := '0';
        ded_o : out std_logic := '0'
    );
end hamming_decoder;

architecture behave_parallel of hamming_decoder is
    signal decode_cycle : unsigned(1 downto 0) := (others=>'0'); --1st check parity, 2nd decode
    signal hamm_syndrome : std_logic_vector(PARITY_BITS-1 downto 0) := (others=>'0');
    signal hamm_decoded_data : std_logic_vector(DATA_WIDTH-1 downto 0) := (others=>'0');
    signal hamm_ne, hamm_sec, hamm_ded, hamm_decode_complete : std_logic := '0';

begin

hamm_cycle: process(clk_i, en_i, rstn_i, decode_cycle)
begin
    if rstn_i = '0' then
        decode_cycle <= (others=>'0');
	elsif rising_edge(clk_i) then
		if en_i = '1' or decode_cycle>0 then
            case decode_cycle is
                when "00"=>
                    decode_cycle <= decode_cycle + 1;
                when "01"=>
                    decode_cycle <= decode_cycle + 1;
                when "10"=>
                    decode_cycle <= (others=>'0');
                when others=>
                    decode_cycle <= (others=>'0');
            end case;
		end if;
	end if;
end process;

hamm_decode: process(clk_i, en_i, rstn_i, decode_cycle, data_i, hamm_syndrome)
begin
	if rstn_i = '0' then
        hamm_syndrome <= (others=>'0');
		hamm_decoded_data <= (others=>'0');
		hamm_decode_complete <= '0';
		hamm_ne <= '0';
		hamm_sec <= '0';
		hamm_ded <= '0';
	elsif rising_edge(clk_i) then
		if en_i = '1' or decode_cycle>0 then
            case decode_cycle is
                when "00"=>
			        hamm_syndrome <= hamming_syndrome(data_i, DATA_WIDTH, PARITY_BITS-EN_DED, EN_DED);
                when "01"=>
                    hamm_decoded_data <= hamming_decode(data_i, hamm_syndrome, DATA_WIDTH, PARITY_BITS-EN_DED, EN_DED);
                    if EN_DED = 0 then
                        if hamm_syndrome(PARITY_BITS-1 downto 0) = (PARITY_BITS-1 downto 0=>'0') then --no error
                            hamm_ne <= '1';
                            hamm_sec <= '0';
                            hamm_ded <= '0';
                        else
                            hamm_ne <= '0';
                            hamm_sec <= '1';
                            hamm_ded <= '0';
                        end if;
                    else
                        if hamm_syndrome(PARITY_BITS-1 downto EN_DED) = (PARITY_BITS-1 downto EN_DED=>'0') and (hamm_syndrome(0)='0') then --no error
                            hamm_ne <= '1';
                            hamm_sec <= '0';
                            hamm_ded <= '0';
                        elsif hamm_syndrome(PARITY_BITS-1 downto EN_DED) = (PARITY_BITS-1 downto EN_DED=>'0') and (hamm_syndrome(0)='1') then --error in parity bit
                            hamm_ne <= '1';
                            hamm_sec <= '1';
                            hamm_ded <= '0';
                        elsif hamm_syndrome(PARITY_BITS-1 downto EN_DED) /= (PARITY_BITS-1 downto EN_DED=>'0') and (hamm_syndrome(0)='1') then --single error
                            hamm_ne <= '0';
                            hamm_sec <= '1';
                            hamm_ded <= '0';
                        elsif hamm_syndrome(PARITY_BITS-1 downto EN_DED) /= (PARITY_BITS-1 downto EN_DED=>'0') and (hamm_syndrome(0)='0') then --double error
                            hamm_ne <= '0';
                            hamm_sec <= '0';
                            hamm_ded <= '1';
                        end if;
                    end if;
                    hamm_decode_complete <= '1';
                when "10"=>
                    hamm_decode_complete <= '0';
                when others=>
                    hamm_syndrome <= (others=>'0');
                    hamm_decoded_data <= (others=>'0');
                    hamm_decode_complete <= '0';
                    hamm_ne <= '0';
                    hamm_sec <= '0';
                    hamm_ded <= '0';
            end case;
		end if;
	end if;
end process;

data_o <= hamm_decoded_data;
done_o <= hamm_decode_complete;
ne_o <= hamm_ne;
sec_o <= hamm_sec;
ded_o <= hamm_ded;

end behave_parallel;