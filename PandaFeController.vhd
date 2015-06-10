----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    14:04:03 09/26/2014 
-- Design Name: 
-- Module Name:    PandaFeController - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: This is component is slow control module for PANDA FE.It receives data form
--				  trb registers and sends it to registers of FE. Exact protocol which is needed
--				  in order to set FE correctly can be found in documentation.
--
-- Dependencies: 
--

-- Revision:0.03 - adding receiving the command form asic
-- Revision:0.02 - ASIC reset functionality added. At the fpga start up the line reset out
--					is driven high for 25 bus_out clock cycles.
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------

--problems: - if write enable (thus setting) comes from pc with higher freq than we can send. We will lose some sendings to asic


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity PandaFeController is 
generic (
   SIMULATION : boolean := true
   );
  port(
  	SYSCLK : in std_logic;
  	RESET_IN : in std_logic;

	--trb net register signals  	
  	REG_READ_ENABLE_IN : in std_logic;
  	REG_WRITE_ENABLE_IN :  in std_logic;
  	REG_DATA_IN : in std_logic_vector(31 downto 0);
  	REG_ADDR_IN : in std_logic_vector(15 downto 0);
  	REG_DATA_OUT : out std_logic_vector(31 downto 0);
  	REG_DATAREADY_OUT : out std_logic;
  	REG_WRITE_ACK_OUT : out std_logic;
  	
  	BUS_CLK_OUT	: out std_logic_vector(2 downto 0);    --clock for asic digital part (feb input)
  	DATA_LINE_OUT : out std_logic_vector(2 downto 0);  --this line is fpga output, feb input data line
  	RESET_LINE_OUT : out std_logic_vector(2 downto 0); --this line resets the asic on panda feb
  	DATA_LINE_IN : in std_logic_vector(2 downto 0)	-- data returning line from asic
  	
  	
  );
end PandaFeController;

architecture Behavioral of PandaFeController is
signal bus_clk : std_logic := '0';
signal userRegData : std_logic_vector(31 downto 0);
signal asicRegData : std_logic_vector(7 downto 0); 
signal dataIndex : unsigned (4 downto 0) := b"10101"; --21
signal writeEnable, writeEnable_q : std_logic;
signal sendFlag : std_logic := '0';
signal bus_clk_cnt : unsigned(11 downto 0)  := (others => '0');
signal data_in_q : std_logic_vector(2 downto 0) := "000";
--shared variable bus_clk_cnt  : integer range 0 to 2090  := 0;
signal write_ack_out, write_ack_out_q, write_ack_out_qq : std_logic;
signal rst_cnt : unsigned (5 downto 0) := b"111111";
signal asic_rst : std_logic  := '0';
signal writeEnableLatch : std_logic := '0';
signal readingData : std_logic := '0';
--FSM 
type state is (reseting, idle, send,closing, finalize);
signal current_state, next_state : state;

begin

clock_generate_process : process(SYSCLK,bus_clk_cnt)
--variable bus_clk_cnt  : integer range 0 to 2090  := 0;
begin
	if rising_edge(SYSCLK) then
		bus_clk_cnt  <=  bus_clk_cnt + 1;
	end if;
end process;


Clock_feq: if SIMULATION= true generate
bus_clk  <= std_logic(bus_clk_cnt(1)); --11
end generate Clock_feq;
Clock_feq1: if SIMULATION= false generate
bus_clk  <= std_logic(bus_clk_cnt(9)); --~100KHz
end generate Clock_feq1;


--BUS_CLK_multiplexing : process (current_state)
--begin
--	if (current_state = reseting or current_state = send) then
--		BUS_CLK_OUT  <= bus_clk;
--	else
--		BUS_CLK_OUT  <= '0';
--	end if;
--end process;





lachtRegData : process(SYSCLK, REG_WRITE_ENABLE_IN)
begin
  if rising_edge(SYSCLK) then
	if(REG_WRITE_ENABLE_IN = '1') then
		userRegData <= x"00"  & REG_DATA_IN(21 downto 0) & b"00";
	else
		userRegData <= userRegData;
	end if;
	writeEnable_q  <= REG_WRITE_ENABLE_IN;
	write_ack_out_qq  <= REG_WRITE_ENABLE_IN;
	write_ack_out_q  <=  write_ack_out_qq;
	write_ack_out  <= write_ack_out_q; 
  end if;
end process;
REG_WRITE_ACK_OUT  <= write_ack_out;



--we make one pulse signal out of incoming  REG_WRITE_ENABLE_IN
writeEnable  <= '1' when REG_WRITE_ENABLE_IN = '1' and writeEnable_q  ='0' else '0';

sendDataToRegister : process (SYSCLK,sendFlag,bus_clk)
begin
	if falling_edge(bus_clk) then
		case  userRegData(22 downto 21) is 
			when "00" =>
				DATA_LINE_OUT(0)  <= userRegData(to_integer(dataIndex));
				DATA_LINE_OUT(1)  <= '0';
				DATA_LINE_OUT(2)  <= '0';
			when "01" =>
				DATA_LINE_OUT(0)  <= '0';
				DATA_LINE_OUT(1)  <= userRegData(to_integer(dataIndex));
				DATA_LINE_OUT(2)  <= '0';
			when "10" =>
				DATA_LINE_OUT(0)  <= '0';
				DATA_LINE_OUT(1)  <= '0';
				DATA_LINE_OUT(2)  <= userRegData(to_integer(dataIndex));
			when others =>
				null;
		end case;	
		--DATA_LINE_OUT  <= userRegData(to_integer(dataIndex));
	end if;
end process;



--ctrDataSending : process (SYSCLK,RESET_IN, writeEnable, dataIndex)
--begin
--	if rising_edge(bus_clk) then
--		if (RESET_IN = '1' or writeEnable = '1') then
--		    sendFlag  <=  '0';
--			dataIndex  <=  (others => '0');
--		elsif (dataIndex < x"15") then
--		    sendFlag  <= '1';
--			dataIndex  <=  dataIndex + x"1";
--		else
--		    sendFlag  <= '0';
--			dataIndex  <= dataIndex;
--		end if;
--	end if;
--end process;


--this process extends the signal write enable so it can be notice by the FSM which works on 100 kHz clock
write_enable_latch : process(writeEnable,current_state,writeEnableLatch,SYSCLK )
begin
if rising_edge(SYSCLK) then
	if(writeEnable = '1' and current_state = idle) then
		writeEnableLatch  <= '1';
	elsif (current_state /= idle) then
		writeEnableLatch  <= '0';
	else
		writeEnableLatch <= writeEnableLatch;
	end if;
end if;

end process;

dataSending_FSM_sync : process(SYSCLK,RESET_IN,bus_clk) 
begin
	if (RESET_IN = '1') then 
		--current_state  <=  reseting;
		current_state <= idle;
	elsif rising_edge(bus_clk) then
			current_state  <= next_state;
	end if;
end process;	

dataSending_FSM : process(SYSCLK, current_state,dataIndex,writeEnable,rst_cnt,userRegData(21),writeEnableLatch) 
begin
   case current_state is
   		when  idle =>
   			if(writeEnableLatch = '1' and userRegData(23) = '0') then
   				next_state  <=  send;
   			elsif (writeEnableLatch = '1' and userRegData(23) = '1') then
   				    next_state  <= reseting;
				else 
					next_state <= idle;
   			end if;
		when reseting => 
   			if(rst_cnt >0) then 	
   				 next_state <= reseting;
   			else
   				next_state  <= idle;
   			end if;	
   		when  send  => 
   			if(dataIndex = b"00010") then
   				next_state  <= closing;
   			else
   				next_state  <= send;
   			end if;
   		when  closing  => 
   			next_state  <=  finalize;
   		when  finalize  => 
   			next_state  <=  idle;
   	end case;
end process;

--ReceivingData_proc : process(bus_clk,dataIndex)
--begin
--   if rising_edge(bus_clk) then
--   	if(dataIndex > 10)then
--   		--null;
--   		asicRegData (to_integer(dataIndex - 11))  <= data_in_q; --does not simulate, why?
--   		--asicRegData  <= asicRegData;
--   	else
--   	   --null;
--   		asicRegData  <= asicRegData;
--  	end if;
--   end if;	
--end process;
ReceivingData_proc : process(SYSCLK,bus_clk,dataIndex)
begin
   if rising_edge(bus_clk) then
   	if(dataIndex < 9 and dataIndex > 0)then
		case  userRegData(22 downto 21) is 
               when "00" =>
                    asicRegData (to_integer(dataIndex)-1)  <= data_in_q(0); --does not simulate, why?
               when "01" =>
                    asicRegData (to_integer(dataIndex)-1)  <= data_in_q(1); --does not simulate, why?
               when "10" =>
                    asicRegData (to_integer(dataIndex)-1)  <= data_in_q(2); --does not simulate, why?
               when others =>
                   null;
           end case;
   	    readingData <= '1';
   	    --asicRegData  <= asicRegData;
   	else
   	   --null;
   		readingData <= '0';
   		asicRegData  <= asicRegData;
  	end if;
   end if;	
end process;


dataIndex_proc : process(SYSCLK,current_state,bus_clk,RESET_IN) 
begin	
	if rising_edge(bus_clk) then
		if(current_state = send and RESET_IN = '0') then
			dataIndex  <= dataIndex - x"1";
		else
			dataIndex   <= (b"10101");--21 dec		
		end if;
	end if;
end process;

rstCnt_proc : process(SYSCLK,current_state,bus_clk,rst_cnt,RESET_IN) 
begin
	if rising_edge(bus_clk) then
		if(current_state = reseting and RESET_IN = '0') then
			rst_cnt  <= rst_cnt - x"1";
		else
			rst_cnt   <= (b"111111");--19 dec		
		end if;
	end if;
end process;

sendResetToAsic : process (SYSCLK,bus_clk,rst_cnt)
begin
	if falling_edge(bus_clk) then
		if(rst_cnt <58 and rst_cnt >32) then
			asic_rst  <= '0';
		else
			asic_rst  <=  '1';
		end if;	
	end if;
end process;

incomingDataFilter : process(SYSCLK,bus_clk)
begin
if falling_edge(bus_clk) then
    data_in_q <=DATA_LINE_IN;
end if;
end process;

---------register write
user_register_read : process (SYSCLK)
begin
if rising_edge(SYSCLK) then
 if (REG_READ_ENABLE_IN  = '1' ) then
    REG_WRITE_ACK_OUT <= '1';
 else
    REG_WRITE_ACK_OUT <= '0';
 end if;
 
 REG_DATAREADY_OUT <= not readingData;
 REG_DATA_OUT<= x"000000" & asicRegData;
end if;
end process; 
 


RESET_LINE_OUT(0)  <= asic_rst when (current_state = reseting ) and (userRegData(22 downto 21) = "00") else '1';
RESET_LINE_OUT(1)  <= asic_rst when (current_state = reseting ) and (userRegData(22 downto 21) = "01") else '1';
RESET_LINE_OUT(2)  <= asic_rst when (current_state = reseting ) and (userRegData(22 downto 21) = "10") else '1';

BUS_CLK_OUT(0)  <=  bus_clk when (current_state /= idle ) and (userRegData(22 downto 21) = "00") else '0';
BUS_CLK_OUT(1)  <=  bus_clk when (current_state /= idle ) and (userRegData(22 downto 21) = "01") else '0';
BUS_CLK_OUT(2)  <=  bus_clk when (current_state /= idle ) and (userRegData(22 downto 21) = "10") else '0';

end Behavioral;




