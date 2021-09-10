LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE IEEE.math_real.ALL;

ENTITY project_reti_logiche IS
	PORT (
		i_clk : IN STD_LOGIC;
		i_rst : IN STD_LOGIC;
		i_start : IN STD_LOGIC;
		i_data : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		o_address : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		o_done : OUT STD_LOGIC;
		o_en : OUT STD_LOGIC;
		o_we : OUT STD_LOGIC;
		o_data : OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
	);
END project_reti_logiche;

ARCHITECTURE Behavioral OF project_reti_logiche IS
	TYPE state_type IS (IDLE, FETCH_DATA, READ_COLUMN, READ_ROW, READ_PIXEL, DUMMY_STATE, SET_EQUALIZATION, VALUE_CHECK, DONE);

	SIGNAL index : STD_LOGIC_VECTOR(15 DOWNTO 0);
	--Offset per la lettura dei dati della immagine nella RAM
	SIGNAL offset : INTEGER RANGE 65535 DOWNTO 0;
	SIGNAL max, min : INTEGER RANGE 255 DOWNTO 0;
	SIGNAL shift : INTEGER RANGE 8 DOWNTO 0;
	SIGNAL shifted_value : STD_LOGIC_VECTOR(15 DOWNTO 0);
	--Segnali degli stati
	SIGNAL curr_state : state_type := DUMMY_STATE;
	-- Codifica di reading_type:
	-- 0 colonna, 1 riga, 2 pixel ricerca estremi, 3 pixel calcolo
	SIGNAL reading_type : INTEGER RANGE 4 DOWNTO 0;

	SIGNAL multiply : INTEGER RANGE 16384 DOWNTO 0;
	--signal column,row : unsigned range from 0 to 128;

BEGIN
	PROCESS (i_clk, i_rst) IS
	BEGIN
		IF (rising_edge(i_rst)) THEN
			--Prepara la prima immagine
			offset <= 3;
			curr_state <= IDLE;
		ELSIF (rising_edge(i_clk)) THEN
			CASE curr_state IS
				WHEN IDLE =>
					--credo vada modificato perchè bisogna leggere precisamente un rising edge, non basta che sia 1.
					IF (i_start = '1') THEN
						curr_state <= FETCH_DATA;
						index <= STD_LOGIC_VECTOR(to_unsigned(offset, 16));
						max <= 0;
						min <= 255;
						reading_type <= 0;
						o_en <= '1';
						o_we <= '0';
					END IF;
				WHEN FETCH_DATA =>
					o_en <= '1';
					o_we <= '0';
					--Prepara lettura colonna
					IF (reading_type = 0) THEN
						o_address <= STD_LOGIC_VECTOR(to_unsigned(offset - 2, 16));
						curr_state <= READ_COLUMN;
						--Prepara lettura riga
					ELSIF (reading_type = 1) THEN
						o_address <= STD_LOGIC_VECTOR(to_unsigned(offset - 1, 16));
						curr_state <= READ_ROW;
						--Prepara lettura pixel
						-- si potrebbe semplificare questo check. da valutare l'introduzione di nuovi stati della macchina per rendere il tutto più leggibile.
					ELSIF ((unsigned(index) < multiply + offset) OR (reading_type = 3)) THEN
						o_address <= index;
						index <= STD_LOGIC_VECTOR(unsigned(index) + 1);
						curr_state <= READ_PIXEL;
					ELSE
						o_done = '1';
						curr_state <= DONE;
					END IF;

				WHEN READ_COLUMN =>
					multiply <= (to_integer(unsigned(i_data)));
					reading_type <= 1;
					curr_state <= FETCH_DATA;

				WHEN READ_ROW =>
					multiply <= (to_integer(unsigned(i_data))) * multiply;
					reading_type <= 2;
					curr_state <= FETCH_DATA;

				WHEN READ_PIXEL =>
					--Ricerca massimo e minimo
					IF (reading_type = 2) THEN
						IF (to_integer(unsigned(i_data)) < min) THEN
							min <= to_integer(unsigned(i_data));

						END IF;
						IF (to_integer(unsigned(i_data)) > max) THEN
							max <= to_integer(unsigned(i_data));

						END IF;
						curr_state <= FETCH_DATA;
						IF (unsigned(index) = multiply + offset) THEN
							curr_state <= SET_EQUALIZATION;
						END IF;

						--Calcolo della trasformata
					ELSIF (reading_type = 3) THEN
						-- casting da riguardare
						shifted_value <= shift_left(to_unsigned(to_integer(unsigned(i_data)) - min, 16), shift);
						curr_state <= VALUE_CHECK;
					END IF;

				WHEN DUMMY_STATE =>
					o_data <= OTHERS => 'U';
					o_done <= 'U';

				WHEN SET_EQUALIZATION =>
					reading_type <= 3;
					index <= offset;
					-- da verificare
					shift <= 8 - floor(log2(max - min + 1));
					curr_state <= FETCH_DATA;

				WHEN VALUE_CHECK =>
					o_en <= '1';
					o_we <= '1';
					--da riguardare questi casting
					o_address <= STD_LOGIC_VECTOR(to_unsigned(to_integer(unsigned(index)) + multiply - 1, 16));
					IF (to_integer(unsigned(shifted_value)) > 255)
						o_data <= STD_LOGIC_VECTOR(to_unsigned(255, 8));
					ELSE
						-- da controllare questo passaggio, sto cercando di portare 
						-- un vettore con 16 bit ad uno a 8 bit. 
						-- La conversione è sicura perchè il numero varrà al massimo 255.
						o_data <= STD_LOGIC_VECTOR(to_unsigned(shifted_value, 8));
					END IF;
					IF (unsigned(index) = multiply + offset) THEN
						reading_type <= 4;
					END IF;
					curr_state <= FETCH_DATA;

				WHEN DONE =>
					IF (falling_edge(start)) THEN
						o_done <= '0';
						curr_state <= IDLE;
					END IF;

			END CASE;
		END IF;
	END PROCESS;
END Behavioral;
