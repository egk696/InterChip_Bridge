----------------------------------------------------------------------------------
-- Created By: Eleftherios Kyriakakis
-- 
-- Design Name: InterChip NoC Communication Bridge for FPGAs
-- Module Name: utils_pack - package
-- Project Name: SEUD-MIST KTH Royal Institute Of Technology
-- Tested Devices:
-- 	FPGA: Artix-7, SmartFusion2
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.all;

--declaration
package utils_pack is
  ---------------------
  --Types
  type tmr_std_logic_bit is array (0 to 2) of std_logic;
  ---------------------
  -- Count ones
  function count_ones_in_vector(data_in : std_logic_vector) return unsigned;

  -- Count zeros
  function count_zeros_in_vector(data_in : std_logic_vector) return unsigned;

  --Converts a binary to BCD encoding
  function to_bcd(input: std_logic_vector(7 downto 0):=(others=>'0')) return std_logic_vector;

  --Converts a BCD to 7 segments display
  function to_segment7(input: std_logic_vector(3 downto 0):=(others=>'0')) return std_logic_vector;

  --Majority per-bit vote on 3 std_logic_vectors
  function majority_vote(data1, data2, data3: std_logic_vector) return std_logic_vector;
  function majority_vote(data1, data2, data3: std_logic) return std_logic;

  --Majority per-bit error detection on 3 std_logic_vectors
  function majority_err_detect(data1, data2, data3: std_logic_vector) return std_logic_vector;
  function majority_err_detect(data1, data2, data3: std_logic) return std_logic;

  --checks if a number is a power of two
  function is_power_of_two(number : integer) return boolean;

  --calculate minimum number of check bits without DED for the specified data_bits (solving for (n+k <= 2^k - 1))
  function calc_hamm_check_bits(data_bits : integer) return integer;

  --hamming encoding, check_bits should be as calculate by function 'calc_hamm_check_bits'
  --ded_en specifies if double error detection parity bit will be calculated into the encoding
  function hamming_encode(data_in : std_logic_vector; data_bits, check_bits: integer; ded_en: integer) return std_logic_vector;

  --hamming status bits or syndrome may be reffered to is the XOR of its parity bit with its related data bits,
  --check_bits should be as calculate by function 'calc_hamm_check_bits'
  --ded_en should be '1' only if double error detection was used in the encoding. If enabled it XORs the whole encoded data calculating the double error detection
  function hamming_syndrome(hamm_encoded_data: std_logic_vector; data_bits, check_bits: integer; ded_en: integer) return std_logic_vector;

  --hamming decoding,
  --check_bits should be as calculate by function 'calc_hamm_check_bits'
  --hamm_syndrome should be as calculated by function 'hamming_syndrome'
  --ded_en should be '1' only if double error detection was used in the encoding. It specifies the lower limit of the hamm_syndrome vector that should be accounted for as single-error check bits
  function hamming_decode(hamm_encoded_data, hamm_syndrome: std_logic_vector; data_bits, check_bits: integer; ded_en: integer) return std_logic_vector;
-----------------------
end package utils_pack;

--body
package body utils_pack is

  -- Count ones
  function count_ones_in_vector(data_in : std_logic_vector) return unsigned is
    variable count : unsigned (data_in'left downto data_in'right) := (others=>'0');
  begin
    for i in data_in'right to data_in'left loop
      if data_in(i) = '1' then
        count := count + 1;
      end if;
    end loop;
    return count;
  end function count_ones_in_vector;

  -- Count zeros
  function count_zeros_in_vector(data_in : std_logic_vector) return unsigned is
    variable count : unsigned (data_in'left downto data_in'right) := (others=>'0');
  begin
    for i in data_in'right to data_in'left loop
      if data_in(i) = '0' then
        count := count + 1;
      end if;
    end loop;
    return count;
  end function count_zeros_in_vector;

  --Converts a binary to BCD encoding
  function to_bcd(input: std_logic_vector(7 downto 0):=(others=>'0')) return std_logic_vector is
    variable bcd: unsigned(11 downto 0) := (others => '0');
    variable bint: unsigned(7 downto 0) := (others => '0');
  begin
    bint := unsigned(input);
    for i in 0 to 7 loop  -- repeating 8 times.
      bcd(11 downto 1) := bcd(10 downto 0);  --shifting the bits.
      bcd(0) := bint(7);
      bint(7 downto 1) := bint(6 downto 0);
      bint(0) :='0';
      if(i < 7 and bcd(3 downto 0) > B"0100") then --add 3 if BCD digit is greater than 4.
        bcd(3 downto 0) := bcd(3 downto 0) + "0011";
      end if;

      if(i < 7 and bcd(7 downto 4) > B"0100") then --add 3 if BCD digit is greater than 4.
        bcd(7 downto 4) := bcd(7 downto 4) + "0011";
      end if;

      if(i < 7 and bcd(11 downto 8) > B"0100") then  --add 3 if BCD digit is greater than 4.
        bcd(11 downto 8) := bcd(11 downto 8) + "0011";
      end if;
    end loop;
    return std_logic_vector(bcd);
  end to_bcd;

  --Converts a BCD to 7 segments display
  function to_segment7(input: std_logic_vector(3 downto 0):=(others=>'0')) return std_logic_vector is
    variable segment7 : std_logic_vector(6 downto 0) := (others => '1');
    variable tmp: std_logic_vector(3 downto 0) := (others => '0');
  begin
    case tmp is
      when "0000" => segment7 := "1000000";
      when "0001" => segment7 := "1111001";
      when "0010" => segment7 := "0100100";
      when "0011" => segment7 := "0110000";
      when "0100" => segment7 := "0110000";
      when "0101" => segment7 := "0110000";
      when "0110" => segment7 := "0110000";
      when "0111" => segment7 := "1111000";
      when "1000" => segment7 := "0000000";
      when "1001" => segment7 := "0011000";
      when others=> segment7 := "1111111";
    end case;
    return segment7;
  end to_segment7;

  --Majority per-bit vote on 3 std_logic_vectors
  function majority_vote(data1, data2, data3: std_logic_vector) return std_logic_vector is
  begin
    return ((data1 and data2) or (data2 and data3) or (data1 and data3));
  end majority_vote;

  --Majority voting based per-bit error detection on 3 std_logic_vectors
  function majority_err_detect(data1, data2, data3: std_logic_vector) return std_logic_vector is
  begin
      return (not(data1) and data3) or (not(data1) and data2) or (data1 and not(data2)) or (data1 and not(data3));
  end majority_err_detect;

  --Majority per-bit vote on 3 std_logic_vectors
  function majority_vote(data1, data2, data3: std_logic) return std_logic is
  begin
    return ((data1 and data2) or (data2 and data3) or (data1 and data3));
  end majority_vote;

  --Majority voting based per-bit error detection on 3 std_logic_vectors
  function majority_err_detect(data1, data2, data3: std_logic) return std_logic is
  begin
      return (not(data1) and data3) or (not(data1) and data2) or (data1 and not(data2)) or (data1 and not(data3));
  end majority_err_detect;

  --checks if a number is a power of two
  function is_power_of_two(number : integer) return boolean is
    variable test_number : integer := number;
  begin
    test_number := number;
    while(test_number mod 2 = 0) loop
      test_number := test_number / 2;
    end loop;
    if test_number > 1 then
      return false;
    else
      return true;
    end if;
  end function is_power_of_two;

  --calculate minimum number of check bits without DED for the specified data_bits (solving for (n+k <= 2^k - 1))
  function calc_hamm_check_bits(data_bits : integer) return integer is
    variable check_bits : integer := 0;
    variable K : integer := 0; 
  begin
    K := integer(log2(real(data_bits)));
    while (2**K-K < data_bits+1) loop
      K := K+1;
    end loop;
    return K;
  end function calc_hamm_check_bits;

  --hamming encoding, check_bits should be as calculate by function 'calc_hamm_check_bits'
  --ded_en specifies if double error detection parity bit will be calculated into the encoding
  function hamming_encode(data_in : std_logic_vector; data_bits, check_bits: integer; ded_en: integer) return std_logic_vector is
    variable hamm_encoded_data : std_logic_vector(data_bits+check_bits-1 downto 0) := (others=>'0');
    variable temp_data_hamm_parity : std_logic_vector(check_bits-1 downto 0) := (others=>'0');
    variable i: integer := 1;
    variable l: integer := 0;
    variable ded_parity: std_logic := '0';
  begin
    report "--HAMM_ENCODE = " & integer'image(to_integer(unsigned(data_in)));
    l := 0;
    --place data in positions
    for j in 1 to check_bits+data_bits loop
      if is_power_of_two(j) or (l >= data_bits) then --index is power of two  thus it is reserved for check bits or it is out of data range
        hamm_encoded_data(j-1) := '0';
      else --not a power of two then its a data bit
        hamm_encoded_data(j-1) := data_in(l);
        report "HAMM_POS[" & integer'image(j-1) & "] := DATA_POS = " & integer'image(l);
        l := l+1;
      end if;
    end loop;
    --calculate parity bits
    for k in 0 to check_bits-1 loop
      report "PARITY[" & integer'image(k) & "] => ";
      i := 2**k;
      while(i <= data_bits+check_bits) loop
        report "POS[" & integer'image(i) & "]";
        report "XOR[" & integer'image(i) & " to " & integer'image(i+(2**k)-1) & "]";
        for j in i to i+(2**k)-1 loop
          if not(is_power_of_two(j)) and (j <= data_bits+check_bits)  then --is data and should calculate for parity
            report "j = " & integer'image(j) & " is " & std_logic'image(temp_data_hamm_parity(k)) & " xor " & std_logic'image(hamm_encoded_data(j-1));
            temp_data_hamm_parity(k) := temp_data_hamm_parity(k) xor hamm_encoded_data(j-1);
          end if;
        end loop;
        i := i + 2*(2**k);
      end loop;
      hamm_encoded_data(2**k-1) := temp_data_hamm_parity(k);
    end loop;
    --ded parity is a final bit that XORs the encoded word
    if ded_en = 1 then
      for d in 0 to check_bits+data_bits-1 loop
        ded_parity := ded_parity xor hamm_encoded_data(d);
      end loop;
      return ded_parity & hamm_encoded_data;
    else
      return hamm_encoded_data;
    end if;
  end function hamming_encode; 

  --hamming status bits or syndrome may be reffered to is the XOR of its parity bit with its related data bits,
  --check_bits should be as calculate by function 'calc_hamm_check_bits'
  --ded_en should be '1' only if double error detection was used in the encoding. If enabled it XORs the whole encoded data calculating the double error detection
  function hamming_syndrome(hamm_encoded_data: std_logic_vector; data_bits, check_bits: integer; ded_en: integer) return std_logic_vector is
    variable temp_syndrome : std_logic_vector(check_bits-1 downto 0) := (others=>'0');
    variable i: integer := 1;
    variable l: integer := 0;
    variable ded_parity: std_logic := '0';
  begin
    for k in 0 to check_bits-1 loop
      report "PARITY[" & integer'image(k) & "] => ";
      i := 2**k;
      while(i <= data_bits+check_bits) loop
        report "POS[" & integer'image(i) & "]";
        report "XOR[" & integer'image(i) & " to " & integer'image(i+(2**k)-1) & "]";
        for j in i to i+(2**k)-1 loop
          if (j <= data_bits+check_bits) then
            temp_syndrome(k) := temp_syndrome(k) xor hamm_encoded_data(j-1);
          end if;
        end loop;
        i := i + 2*(2**k);
      end loop;
    end loop;
    if ded_en = 1 then
      for d in 0 to check_bits+data_bits loop --count 1 extra
        ded_parity := ded_parity xor hamm_encoded_data(d);
      end loop;
      return temp_syndrome & ded_parity;
    else
      return temp_syndrome;
    end if;
  end function hamming_syndrome;

  --hamming decoding,
  --check_bits should be as calculate by function 'calc_hamm_check_bits'
  --hamm_syndrome should be as calculated by function 'hamming_syndrome'
  --ded_en should be '1' only if double error detection was used in the encoding. It specifies the lower limit of the hamm_syndrome vector that should be accounted for as single-error check bits
  function hamming_decode(hamm_encoded_data, hamm_syndrome: std_logic_vector; data_bits, check_bits: integer; ded_en: integer) return std_logic_vector is
      variable healed_data : std_logic_vector(data_bits+check_bits-1 downto 0) := (others=>'0');
      variable hamm_decoded_data : std_logic_vector(data_bits-1 downto 0) := (others=>'0'); 
      variable i: integer := 1;
      variable l: integer := 0;
    begin
      report "--HAMM_DECODE = " & integer'image(to_integer(unsigned(hamm_encoded_data)));
      if ded_en = 0 then
        if hamm_syndrome(check_bits-1 downto 0) = (check_bits-1 downto 0=>'0') then --no error
          healed_data := hamm_encoded_data(data_bits+check_bits-1 downto 0);
        else
          for i in 0 to data_bits+check_bits-1 loop
            if i = to_integer(unsigned(hamm_syndrome(check_bits-1 downto ded_en))-1) then
              healed_data(i) := not(hamm_encoded_data(i));
              assert false report "bit_flip_found: index[" & integer'image(i) & "] healing to = " & integer'image(to_integer(unsigned(healed_data))) severity warning;
            else
              healed_data(i) := hamm_encoded_data(i);
            end if;
          end loop;
        end if;
      else
        if hamm_syndrome(check_bits-1 downto ded_en) = (check_bits-1 downto ded_en=>'0') and (hamm_syndrome(0)='0') then --no error
          healed_data := hamm_encoded_data(data_bits+check_bits-1 downto 0);
        elsif hamm_syndrome(check_bits-1 downto ded_en) = (check_bits-1 downto ded_en=>'0') and (hamm_syndrome(0)='1') then --error in parity bit
          healed_data := hamm_encoded_data(data_bits+check_bits-1 downto 0);
        elsif hamm_syndrome(check_bits-1 downto ded_en) /= (check_bits-1 downto ded_en=>'0') and (hamm_syndrome(0)='1') then --single error
          for i in 0 to data_bits+check_bits-1 loop
            if i = to_integer(unsigned(hamm_syndrome(check_bits-1 downto ded_en))-1) then
              healed_data(i) := not(hamm_encoded_data(i));
              assert false report "bit_flip_found: index[" & integer'image(i) & "] healing to = " & integer'image(to_integer(unsigned(healed_data))) severity warning;
            else
              healed_data(i) := hamm_encoded_data(i);
            end if;
          end loop;
        elsif hamm_syndrome(check_bits-1 downto ded_en) /= (check_bits-1 downto ded_en=>'0') and (hamm_syndrome(0)='0') then --double error
          healed_data := hamm_encoded_data(data_bits+check_bits-1 downto 0);
        end if;
      end if;
      --pickout data from encoded word
      l := 0;
      for j in 1 to check_bits+data_bits loop
        if not(is_power_of_two(j)) and (l < data_bits) then --not a power of two then its a data bit
          hamm_decoded_data(l) := healed_data(j-1);
          report "HAMM_POS[" & integer'image(j-1) & "] := DATA_POS = " & integer'image(l);
          l := l+1;
        end if;
      end loop;
      return hamm_decoded_data;
    end function hamming_decode;

end package body utils_pack;