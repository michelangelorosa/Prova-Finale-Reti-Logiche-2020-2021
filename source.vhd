library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity project_reti_logiche is
port (
i_clk : in std_logic;
i_rst : in std_logic;
i_start : in std_logic;
i_data : in std_logic_vector(7 downto 0);
o_address : out std_logic_vector(15 downto 0);
o_en : out std_logic;
o_we : out std_logic
);
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is
	type state_type is (IDLE,FETCH_DATA,READ_COLUMN,READ_ROW,READ_PIXEL);

	signal index : std_logic_vector(15 downto 0);
	--Offset per la lettura dei dati della immagine nella RAM
	signal offset : unsigned (65535 downto 0);
	signal max,min : integer range 255 downto 0;
	--signal shift : unsigned range 8 downto 0;
	--Segnali degli stati
	signal curr_state : state_type;
	-- Codifica di reading_type:
	-- 0 colonna, 1 riga, 2 pixel ricerca estremi, 3 pixel calcolo
	signal reading_type : integer range 3 downto 0;
	
	signal multiply : integer range 16384 downto 0;
	--signal column,row : unsigned range from 0 to 128;
	
begin 
	process (i_clk,i_rst) is
		begin
			if(i_rst='1') then
				--Prepara la prima immagine
				offset <= to_unsigned(2,1);
				curr_state <= IDLE;
			elsif(rising_edge(i_clk)) then
				case curr_state	is
					when IDLE =>
						if(i_start = '1') then
							curr_state <= FETCH_DATA;
							index <= std_logic_vector(unsigned(offset));
							max<=0;
							min<=255;
							reading_type <= 0;
						end if;
					
					when FETCH_DATA =>
							o_en <= '1';
							o_we <= '0';
							--Prepara lettura colonna
							if(reading_type=0) then
								o_address <= std_logic_vector(unsigned(offset-2));
								curr_state <= READ_COLUMN;
							--Prepara lettura riga
							elsif(reading_type=1) then
								o_address <= std_logic_vector(unsigned(offset-1));
								curr_state <= READ_ROW;
							--Prepara lettura pixel
							elsif(unsigned(index)<multiply+offset) then
									o_address <= index;
									index <= std_logic_vector(unsigned(index)+1);
									curr_state <= READ_PIXEL;
							end if;
								
						
					when READ_COLUMN =>
							multiply <= to_integer(unsigned(i_data));
							reading_type <= 1;
							curr_state <= FETCH_DATA;
					
					when READ_ROW =>
							multiply <= (to_integer(unsigned(i_data)))*multiply;
							reading_type <= 2;
							curr_state <= FETCH_DATA;
							
					when READ_PIXEL =>
							--Ricerca massimo e minimo
							if(reading_type=2) then
								if(to_integer(unsigned(i_data))<min) then
									min<=to_integer(unsigned(i_data));
								end if;
								if(to_integer(unsigned(i_data))>max) then
									max<=to_integer(unsigned(i_data));
								end if;
							
							--Calcolo della trasformata
							--else
							
							end if;	
				end case;
			end if;
		end process;
end Behavioral;
