----------------------------------------------------------------------------------
-- Created By: Eleftherios Kyriakakis
-- 
-- Design Name: InterChip NoC Communication Bridge for FPGAs
-- Module Name: rx_sipo_channel - behave
-- Project Name: SEUD-MIST KTH Royal Institute Of Technology
-- Tested Devices:
-- 	FPGA: Artix-7, SmartFusion2
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.all;
use work.utils_pack.all;

entity rx_sipo_channel is
	generic(
		DATA_WIDTH : Integer := 60;
		TX_WIDTH : Integer := 2;
		FIFO_DEPTH : Integer := 64;
		EN_HAMMING: Integer := 1;
		EN_DED: Integer := 0
	);
	port(
		clk_i : in std_logic := '0';
		rstn_i : in std_logic := '1';
		ss_i : in std_logic := '0';
		sck_i : in std_logic := '0';
		shift_i	: in std_logic_vector(TX_WIDTH-1 downto 0) := (others=>'0');
		rx_busy_o : out std_logic := '0';
		data_o : out std_logic_vector(DATA_WIDTH-1 downto 0) := (others=>'0');
		ready_o : out std_logic := '0';
		ne_o : out std_logic := '0';
		sec_o : out std_logic := '0';
		ded_o : out std_logic := '0'
	);
end rx_sipo_channel;

architecture behave of rx_sipo_channel is
	----------------------------------
	constant PARITY_BITS : integer := (calc_hamm_check_bits(DATA_WIDTH) + EN_DED) * EN_HAMMING;
	constant SHIFT_STAGES : integer := integer(ceil(real(DATA_WIDTH+PARITY_BITS)/real(TX_WIDTH)));
	----------------------------------
	signal rx_done : std_logic := '0';
	----------------------------------
	signal current_data_out : std_logic_vector(DATA_WIDTH-1 downto 0) := (others=>'0');
	signal next_data_out : std_logic_vector(DATA_WIDTH+PARITY_BITS-1 downto 0) := (others=>'0');
	signal ready_out, valid_out : std_logic := '0';
	----------------------------------
	signal fifo_wr_data, fifo_rd_data : std_logic_vector(DATA_WIDTH+PARITY_BITS-1 downto 0) := (others=>'0');
	signal fifo_empty, fifo_full : std_logic := '0';
	signal fifo_reset : std_logic := '0';
	signal rd_fifo_en, wr_fifo_en : std_logic := '0';
	----------------------------------
	signal hamm_en : std_logic := '0';
	signal ne_out, sec_out, ded_out : std_logic := '0';
	----------------------------------
begin

rx_s2p: entity work.serial2parallel
generic map(
	DATA_WIDTH=>DATA_WIDTH+PARITY_BITS,
	TX_WIDTH=>TX_WIDTH
)
port map(
	sck_i=>sck_i,
	en_i=>ss_i,
	shift_i=>shift_i,
	done_o=>rx_done,
	data_o=>fifo_wr_data
);

rx_busy_o <= not(ss_i) and not(rx_done);
fifo_reset <= not(rstn_i);
wr_fifo_en <= not(fifo_full) and rx_done;

fifo_inst: entity work.async_fifo(behave_v2)
generic map(
	DATA_WIDTH=>DATA_WIDTH+PARITY_BITS,
	FIFO_DEPTH=>FIFO_DEPTH
)
port map(
	wr_clk=>sck_i,
	wr_en=>wr_fifo_en,
	wr_data=>fifo_wr_data,
	--
	rd_clk=>clk_i,
	rd_en=>rd_fifo_en,
	rd_data=>fifo_rd_data,
	full_flag=>fifo_full,
	empty_flag=>fifo_empty,
	clear=>fifo_reset
);

hamm: if EN_HAMMING = 1 generate
	read_fifo: process(clk_i, fifo_empty)
	begin
		if rising_edge(clk_i) then
			if rd_fifo_en='0' and fifo_empty='0' then
				rd_fifo_en <= '1';
			elsif rd_fifo_en = '1' then
				rd_fifo_en <= '0';
				next_data_out <= fifo_rd_data;
				hamm_en <= '1';
			elsif hamm_en = '1' and ready_out='1' then
				hamm_en <= '0';
			end if;
		end if;
	end process;
	decoder_inst: entity work.hamming_decoder(behave_parallel)
	generic map(
		DATA_WIDTH=>DATA_WIDTH,
		PARITY_BITS=>PARITY_BITS,
		EN_DED=>EN_DED
	)
	port map(
		clk_i=>clk_i,
		rstn_i=>rstn_i,
		en_i=>hamm_en,
		data_i=>next_data_out,
		data_o=>current_data_out,
		done_o=>ready_out,
		ne_o=>ne_out,
		sec_o=>sec_out,
		ded_o=>ded_out
	);
end generate;
nohamm: if EN_HAMMING = 0 generate
	read_fifo: process(clk_i, fifo_empty)
	begin
		if rising_edge(clk_i) then
			if rd_fifo_en='0' and fifo_empty='0' then
				rd_fifo_en <= '1';
				current_data_out <= fifo_rd_data;
			elsif rd_fifo_en = '1' then
				rd_fifo_en <= '0';
				ready_out <= '1';
			elsif ready_out = '1' then
				ready_out <= '0';
			end if;
		end if;
	end process;
	ne_out<='1';
	sec_out<='0';
	ded_out<='0';
end generate;

valid_out <= ready_out;
data_o <= current_data_out;
ready_o <= valid_out;
ne_o <= ne_out;
sec_o <=sec_out;
ded_o <=ded_out;

end behave;