----------------------------------------------------------------------------------
-- Created By: Eleftherios Kyriakakis
-- 
-- Design Name: InterChip NoC Communication Bridge for FPGAs
-- Module Name: tx_piso_channel - behave
-- Project Name: SEUD-MIST KTH Royal Institute Of Technology
-- Tested Devices:
-- 	FPGA: Artix-7, SmartFusion2
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.all;
use work.utils_pack.all;

entity tx_piso_channel is
	generic(
		DATA_WIDTH : Integer := 60;
		TX_WIDTH : Integer := 4;
		FIFO_DEPTH : Integer := 64;
		EN_HAMMING: Integer := 1;
		EN_DED: Integer := 1
	);
	port(
		clk_i : in std_logic := '0';
		rstn_i : in std_logic := '1';
		load_en : in std_logic := '0';
		data_i : in std_logic_vector(DATA_WIDTH-1 downto 0) := (others=>'0');
		tx_clk_i : in std_logic := '0';
		tx_busy_o : out std_logic := '0';
		shift_o	: out std_logic_vector(TX_WIDTH-1 downto 0) := (others=>'Z');
		ss_o : out std_logic := '1'
	);
end tx_piso_channel;

architecture behave of tx_piso_channel is
	-----------------------------------
	constant PARITY_BITS : integer := (calc_hamm_check_bits(DATA_WIDTH) + EN_DED) * EN_HAMMING ;
	constant SHIFT_STAGES : integer := integer(ceil(real(DATA_WIDTH+PARITY_BITS)/real(TX_WIDTH)));
	-----------------------------------
	signal rd_fifo_en, wr_fifo_en : std_logic := '0';
	signal fifo_rd_data, fifo_wr_data : std_logic_vector(DATA_WIDTH+PARITY_BITS-1 downto 0);
	signal fifo_full, fifo_empty : std_logic := '0';
    signal fifo_rst : std_logic := '0';
	----------------------------------
	signal hamm_done : std_logic := '0';
	----------------------------------
	signal tx_start : std_logic := '0';
	signal tx_data : std_logic_vector(DATA_WIDTH+PARITY_BITS-1 downto 0) := (others=>'0');
	signal tx_done : std_logic := '0';
	signal tx_busy : std_logic := '0';
	----------------------------------
begin

fifo_rst <= not(rstn_i);
tx_busy_o <= tx_busy;

hamm: if EN_HAMMING = 1 generate
	encoder_inst: entity work.hamming_encoder(behave_parallel)
	generic map(
		DATA_WIDTH=>DATA_WIDTH,
		PARITY_BITS=>PARITY_BITS,
		EN_DED=>EN_DED
	)
	port map(
		clk_i=>clk_i,
		en_i=>load_en,
		data_i=>data_i,
		data_o=>fifo_wr_data,
		done_o=>hamm_done
	);
	wr_fifo_en <= hamm_done and not(fifo_full);
end generate;
nohamm: if EN_HAMMING = 0 generate
	fifo_wr_data <= data_i;
	wr_fifo_en <= load_en and not(fifo_full);
end generate;

fifo_inst: entity work.async_fifo(behave_v2)
generic map(
	DATA_WIDTH=>DATA_WIDTH+PARITY_BITS,
	FIFO_DEPTH=>FIFO_DEPTH
)
port map(
	wr_clk=>clk_i,
	wr_en=>wr_fifo_en,
	wr_data=>fifo_wr_data,
	--
	rd_clk=>tx_clk_i,
	rd_en=>rd_fifo_en,
	rd_data=>fifo_rd_data,
	full_flag=>fifo_full,
	empty_flag=>fifo_empty,
	clear=>fifo_rst
);

fetch_fifo: process(clk_i, tx_busy, fifo_empty, rd_fifo_en, tx_start, fifo_rd_data)
begin
	if rising_edge(clk_i) then
		if fifo_empty='0' and tx_start='0' and tx_busy='0' then
			rd_fifo_en <= '1';
			tx_data <= fifo_rd_data;
		end if;
		if rd_fifo_en = '1' then
			rd_fifo_en <= '0';
			tx_start <= '1';
		elsif tx_busy = '1' then
			tx_start <= '0';
		end if;
	end if;
end process;

tx_p2s: entity work.parallel2serial
generic map(
	DATA_WIDTH=>DATA_WIDTH+PARITY_BITS,
	TX_WIDTH=>TX_WIDTH
)
port map(
	clk_i=>clk_i,
	sck_i=>tx_clk_i,
	en_i=>tx_start,
	data_i=>tx_data,
	busy_o=>tx_busy,
	done_o=>tx_done,
	shift_o=>shift_o,
    ss_o=>ss_o
);


end behave;