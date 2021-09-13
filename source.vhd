----------------------------------------------------------------------------------
--
-- Prova Finale (Progetto di Reti Logiche)
-- 15/9/2021
-- Prof. Gianluca Palermo - Anno 2020/2021
--
-- Gabriele Passoni
-- Michelangelo Rosa
-- 
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

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
    TYPE state_type IS (SLEEP_STATE, IDLE, FETCH_DATA, READ_DIM, READ_PIXEL, SET_EQUALIZATION, VALUE_CHECK, DONE, WAIT_RAM);

    SIGNAL index : 					STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL max, min : 				INTEGER RANGE 255 DOWNTO 0;
    SIGNAL shift : 					INTEGER RANGE 8 DOWNTO 0;
    SIGNAL shifted_value : 			STD_LOGIC_VECTOR(15 DOWNTO 0);
    --Segnali degli stati
    SIGNAL curr_state, next_state : state_type;
    -- Codifica di reading_type:
    -- 0 colonna, 1 riga, 2 pixel ricerca estremi, 3 pixel calcolo
    SIGNAL reading_type : INTEGER RANGE 3 DOWNTO 0;
    SIGNAL multiply : INTEGER RANGE 16384 DOWNTO 0;

BEGIN
    PROCESS (i_clk, i_rst) IS
    BEGIN
        IF (rising_edge(i_clk)) THEN
            CASE curr_state IS
----------------------------------------------------------------------------------
                WHEN SLEEP_STATE =>
                    curr_state <= SLEEP_STATE;
----------------------------------------------------------------------------------
                WHEN IDLE =>
                    IF (i_start = '1') THEN
                        curr_state <= FETCH_DATA;
                        index <= STD_LOGIC_VECTOR(to_unsigned(2, 16));
                        max <= 0;
                        min <= 255;
                        reading_type <= 0;
                    END IF;
----------------------------------------------------------------------------------
                WHEN FETCH_DATA =>
                    o_en <= '1';
                    o_we <= '0';
                    --Lettura colonna
                    IF (reading_type = 0) THEN
                        o_address <= STD_LOGIC_VECTOR(to_unsigned(0, 16));
                        curr_state <= WAIT_RAM;
                        next_state <= READ_DIM;
                    --Lettura riga
                    ELSIF (reading_type = 1) THEN
                        o_address <= STD_LOGIC_VECTOR(to_unsigned(1, 16));
                        curr_state <= WAIT_RAM;
                        next_state <= READ_DIM;
                    --Lettura pixel
                    ELSIF (unsigned(index) < multiply + 2) THEN
                        o_address <= index;
                        index <= STD_LOGIC_VECTOR(unsigned(index) + 1);
                        curr_state <= WAIT_RAM;
                        next_state <= READ_PIXEL;
                    --Computazione terminata
					ELSE
                        o_done <= '1';
                        curr_state <= DONE;
                    END IF;
----------------------------------------------------------------------------------
                WHEN WAIT_RAM =>
                    curr_state <= next_state;
----------------------------------------------------------------------------------
                WHEN READ_DIM =>
                    if(reading_type = 0) then
						multiply <= (to_integer(unsigned(i_data)));
						reading_type <= 1;
                    else
						multiply <= (to_integer(unsigned(i_data))) * multiply;
						reading_type <= 2;
                    end if;
                    curr_state <= FETCH_DATA;
----------------------------------------------------------------------------------
                WHEN READ_PIXEL =>
                    --Ricerca massimo e minimo
                    IF (reading_type = 2) THEN
                        IF (to_integer(unsigned(i_data)) < min) THEN
                            min <= to_integer(unsigned(i_data));
                        END IF;
                        IF (to_integer(unsigned(i_data)) > max) THEN
                            max <= to_integer(unsigned(i_data));
                        END IF;
                        IF (unsigned(index) = multiply + 2) THEN
                            curr_state <= SET_EQUALIZATION;
                        ELSE
                            curr_state <= FETCH_DATA;
                        END IF;
                    --Calcolo dello shift
                    ELSIF (reading_type = 3) THEN
                        shifted_value <= STD_LOGIC_VECTOR(shift_left(to_unsigned(to_integer(unsigned(i_data)) - min, 16), shift));
                        curr_state <= VALUE_CHECK;
                    END IF;
----------------------------------------------------------------------------------
                WHEN SET_EQUALIZATION =>
                    reading_type <= 3;
                    index <= STD_LOGIC_VECTOR(to_unsigned(2, 16));
                    IF 		(max - min + 1 > 255) 	THEN
                        shift <= 0;
                    ELSIF 	(max - min + 1 > 127) 	THEN
                        shift <= 1;
                    ELSIF 	(max - min + 1 > 63) 	THEN
                        shift <= 2;
                    ELSIF 	(max - min + 1 > 31) 	THEN
                        shift <= 3;
                    ELSIF 	(max - min + 1 > 15) 	THEN
                        shift <= 4;
                    ELSIF 	(max - min + 1 > 7) 	THEN
                        shift <= 5;
                    ELSIF 	(max - min + 1 > 3) 	THEN
                        shift <= 6;
                    ELSIF 	(max - min + 1 > 1) 	THEN
                        shift <= 7;
                    ELSE
                        shift <= 8;
                    END IF;
                    curr_state <= FETCH_DATA;
----------------------------------------------------------------------------------
                WHEN VALUE_CHECK =>
                    o_en <= '1';
                    o_we <= '1';
                    o_address <= STD_LOGIC_VECTOR(to_unsigned(to_integer(unsigned(index)) + multiply - 1, 16));
                    IF (to_integer(unsigned(shifted_value)) > 255) THEN
                        o_data <= STD_LOGIC_VECTOR(to_unsigned(255, 8));
                    ELSE
                        -- La conversione è sicura perchè il numero varrà al massimo 255.
                        o_data <= STD_LOGIC_VECTOR(to_unsigned(to_integer(unsigned(shifted_value)), 8));
                    END IF;
                    curr_state <= FETCH_DATA;
----------------------------------------------------------------------------------
                WHEN DONE =>
                    IF (i_start = '0') THEN
                        o_done <= '0';
                        curr_state <= IDLE;
                    END IF;
----------------------------------------------------------------------------------					
            END CASE;
            IF (i_rst = '1') THEN
                curr_state <= IDLE;
            END IF;
        END IF;
    END PROCESS;
END Behavioral;
