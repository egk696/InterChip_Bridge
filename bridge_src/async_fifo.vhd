----------------------------------------------------------------------------------
-- Created By: Eleftherios Kyriakakis
-- 
-- Design Name: InterChip NoC Communication Bridge for FPGAs
-- Module Name: async_fifo - behave
-- Project Name: SEUD-MIST KTH Royal Institute Of Technology
-- Tested Devices:
-- 	FPGA: Artix-7, SmartFusion2
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.all;
 
entity async_fifo is
	generic (
	    DATA_WIDTH    : integer := 64;
	    FIFO_DEPTH    : integer := 64
	);
	port(
		--Write port
		wr_clk : in std_logic := '0';
		wr_en : in std_logic := '0';
		wr_data : in std_logic_vector(DATA_WIDTH-1 downto 0);
		--Read port
		rd_clk : in std_logic := '0';
		rd_en : in std_logic := '0';
		rd_data : out std_logic_vector(DATA_WIDTH-1 downto 0);
		--Status port
		full_flag : out std_logic := '0';
		empty_flag : out std_logic := '1';
		--Control
		clear : in std_logic := '0'
	);
end async_fifo;

architecture behave_v2 of async_fifo is
	--constants
	constant RAM_ADDR_WIDTH : integer := integer(ceil(log2(real(FIFO_DEPTH))));
	--declare signals
	signal wr_ptr_gray, wr_ptr_bin, wr_ptr_gray_reg1, wr_ptr_gray_synced, wr_ptr_bin_synced : std_logic_vector(RAM_ADDR_WIDTH-1 downto 0) := (others=>'0');
	signal rd_ptr_gray, rd_ptr_bin, rd_ptr_gray_reg1, rd_ptr_gray_synced, rd_ptr_bin_synced : std_logic_vector(RAM_ADDR_WIDTH-1 downto 0) := (others=>'0');
	signal ram_read_en : std_logic := '0';
	signal ram_write_en : std_logic := '0';
	signal check_full : std_logic := '0';
	signal check_empty : std_logic := '1';
	--attributes
	attribute ASYNC_REG : string;
    attribute ASYNC_REG of wr_ptr_gray_reg1 : signal is "TRUE";
    attribute ASYNC_REG of rd_ptr_gray_reg1 : signal is "TRUE";
begin

full_flag <= check_full;
empty_flag <= check_empty;

check_full <= '1' when std_logic_vector(unsigned(wr_ptr_bin)+1)=rd_ptr_bin_synced else '0'; --synced to wr_clk
check_empty <= '1' when std_logic_vector(unsigned(rd_ptr_bin))=wr_ptr_bin_synced else '0'; --synced to rd_clk

--enable r/w signals for counters and ram
ram_write_en <= not(check_full) and wr_en;
ram_read_en <= not(check_empty) and rd_en;

sync2FF_wr_ptr_gray: process(rd_clk, wr_ptr_gray, wr_ptr_gray_reg1)
begin
	if rising_edge(rd_clk) then
		wr_ptr_gray_reg1 <= wr_ptr_gray;
		wr_ptr_gray_synced <= wr_ptr_gray_reg1;
--		if std_logic_vector(unsigned(rd_ptr_bin)+1)=wr_ptr_bin_synced then
--		  check_empty <= '1';
--		else
--		  check_empty <= '0';
--		end if;
	end if;
end process;

sync2FF_rd_ptr_gray: process(wr_clk, rd_ptr_gray, rd_ptr_gray_reg1)
begin
	if rising_edge(wr_clk) then
		rd_ptr_gray_reg1 <= rd_ptr_gray;
		rd_ptr_gray_synced <= rd_ptr_gray_reg1;
--		if std_logic_vector(unsigned(wr_ptr_bin)+1)=rd_ptr_bin_synced then
--		  check_full <= '1';
--		else
--		  check_full <= '0';
--		end if;
	end if;
end process;

--instantiations
wr_ptr_gray2bin_inst: entity work.grey_converter
generic map(
    DATA_WIDTH=>RAM_ADDR_WIDTH
)
port map(
    sel=>'0',
    data=>wr_ptr_gray,
    data_out=>wr_ptr_bin
);

wr_ptr_gray_counter_inst: entity work.gray_counter
generic map(
	COUNTER_WIDTH=>RAM_ADDR_WIDTH,
	INIT_VALUE=>0
)
port map(
	clk=>wr_clk,
	en=>ram_write_en,
	rst=>clear,
	grey_count=>wr_ptr_gray
);

wr_ptr_synced_gray2bin_inst: entity work.grey_converter
generic map(
    DATA_WIDTH=>RAM_ADDR_WIDTH
)
port map(
    sel=>'0',
    data=>wr_ptr_gray_synced,
    data_out=>wr_ptr_bin_synced
);

rd_ptr_gray2bin_inst: entity work.grey_converter
generic map(
    DATA_WIDTH=>RAM_ADDR_WIDTH
)
port map(
    sel=>'0',
    data=>rd_ptr_gray,
    data_out=>rd_ptr_bin
);

rd_ptr_gray_counter_inst: entity work.gray_counter
generic map(
	COUNTER_WIDTH=>RAM_ADDR_WIDTH,
	INIT_VALUE=>0
)
port map(
	clk=>rd_clk,
	en=>ram_read_en,
	rst=>clear,
	grey_count=>rd_ptr_gray
);

rd_ptr_synced_gray2bin_inst: entity work.grey_converter
generic map(
    DATA_WIDTH=>RAM_ADDR_WIDTH
)
port map(
    sel=>'0',
    data=>rd_ptr_gray_synced,
    data_out=>rd_ptr_bin_synced
);

tdp_ram_inst: entity work.true_dual_port_ram
generic map(
	DATA_WIDTH=>DATA_WIDTH,
	ADDR_WIDTH=>RAM_ADDR_WIDTH
)
port map(
	-- Port A
    a_clk=>wr_clk,
    a_wr=>ram_write_en,
    a_addr=>wr_ptr_bin,
    a_din=>wr_data,
     
    -- Port B
    b_clk=>rd_clk,
    b_rd=>ram_read_en,
    b_addr=>rd_ptr_bin,
    b_dout=>rd_data
);


end behave_v2;