library IEEE;
        use IEEE.std_logic_1164.all;
        use IEEE.std_logic_unsigned.all;
library work;
        use work.camera.all ;

entity send_picture is
	generic(NB_RAW_DATA : natural := 0);
	port(
 		clk : in std_logic; 
 		arazb : in std_logic; 
 		pixel_clock, hsync, vsync : in std_logic; 
 		pixel_data_in : in std_logic_vector(7 downto 0 ); 
		raw_data_in : in std_logic_vector(7 downto 0 );
		raw_data_available : in std_logic ;
		read_raw_data : out std_logic ;
 		data_out : out std_logic_vector(7 downto 0 ); 
		output_ready : in std_logic;
 		send : out std_logic
	); 
end send_picture;

architecture systemc of send_picture is
	constant VSYNC_CHAR : std_logic_vector(7 downto 0) := "01010101"; 
	constant HSYNC_CHAR : std_logic_vector(7 downto 0) := "10101001";
	TYPE send_state IS (WAIT_PIXEL, WRITE_DATA, WAIT_SYNC) ; 
	signal state : send_state ; 
	signal isControlChar : std_logic ; 
	signal end_sig : std_logic ; 
	signal select_end : std_logic_vector(1 downto 0 ) ;
	signal fifo_empty, fifo_full, fifo_rd, fifo_wr : std_logic ;
	signal fifo_data_in : std_logic_vector(7 downto 0);
	signal raw_data_counter : std_logic_vector(7 downto 0);
	begin
	fifo_64x8_0 : fifo_Nx8 -- output fifo
		generic map(N => 128)
		port map(
 		clk => clk, 
		arazb => arazb,
		sraz => '0',
 		wr => fifo_wr , 
		rd => fifo_rd, 
		empty => fifo_empty , full => fifo_full, data_rdy => send,
 		data_out => data_out,  
 		data_in => fifo_data_in
	); 
	
	-- send_picture_process
	process(clk, arazb)
		 begin
		 	if  NOT arazb = '1'  then
				raw_data_counter <= (others => '0');
		 		state <= wait_pixel ;
		 	elsif  clk'event and clk = '1'  then
		 		case state is
		 			when wait_pixel =>  
		 				if  pixel_clock = '1'  then --send pixel value
		 					select_end <= (others => '0') ; --end signal is pxclk falling edge
							fifo_data_in <= pixel_data_in(7 downto 1) & (pixel_data_in(0) AND (NOT isControlChar));
		 					fifo_wr <= '1' ;
--							state <= write_data ; -- least significant bit can be modified if pixel value equals hsync or vsync char
							state <= wait_sync ;
						elsif  vsync = '1'  then
		 					fifo_data_in <= VSYNC_CHAR ; 
		 					select_end <= "01" ; --end signal is pxclk vsync edge
		 					fifo_wr <= '1' ;
--							state <= write_data ;
							state <= wait_sync ;
		 				elsif  hsync = '1'  then
		 					fifo_data_in <= HSYNC_CHAR ; --end signal is hsync falling edge
		 					select_end <= "10" ; 
		 					fifo_wr <= '1' ;
--							state <= write_data ;
							state <= wait_sync ;
						else
							read_raw_data <= '0' ;
							fifo_wr <= '0' ;
		 				end if ;
--		 			when write_data => 
--						read_raw_data <= '0' ;
--						fifo_wr <= '0' ;
--		 				state <= wait_sync ; -- one dummy cycle to ensure data is written (could be removed but work this way)
		 			when wait_sync => 
						read_raw_data <= '0' ;
						fifo_wr <= '0' ;
						if vsync = '1' and raw_data_counter < NB_RAW_DATA then
							if raw_data_available = '1' then
								read_raw_data <= '1' ;
								fifo_data_in <= raw_data_in ;
							else
								read_raw_data <= '0' ;
								fifo_data_in <= (others => '0') ;
							end if ;
							--must set fifo write signal some way
							raw_data_counter <= raw_data_counter + 1 ;
							fifo_wr <= '1' ;
						else
							read_raw_data <= '0' ;
							fifo_wr <= '0' ;
						end if;
		 				if  end_sig = '1'  then
							raw_data_counter <= (others => '0');
		 					state <= wait_pixel ;
		 				end if ;
		 			when others => 
		 				state <= wait_pixel ;
		 		end case ;
				end if ;
		 end process;  

	--process(clk) -- why on falling edge ?
	--begin 
	--if clk'event and clk = '0' then
	--	  case state is
	--			when write_data => 
	--				fifo_wr <= '1' ;
	--			when others => 
	--				fifo_wr <= '0' ;
	--		end case;
	--end if ;
	--end process ;

	-- end_sig_mux
	process(pixel_clock, hsync, vsync, select_end)
		 begin
		 	if  conv_integer(select_end) = 1  then
		 		end_sig <= NOT vsync ;
		 	elsif  conv_integer(select_end) = 2  then
				end_sig <= vsync OR (NOT hsync);
			elsif conv_integer(select_end) = 0 then
				end_sig <= NOT pixel_clock ; 
			else 
				end_sig <= NOT pixel_clock ;
		 	end if ;
		 end process;  

isControlChar <= '1' when (pixel_data_in = "01010101") else -- equals VSYNC
					  '1' when (pixel_data_in = "10101001") else -- equals HSYNC
					  '0';
	
fifo_rd <= '1' when output_ready = '1' and fifo_empty = '0' else
			  '0' ; --fifo is read when receiver is ready and when fifo is not empty
end systemc ;