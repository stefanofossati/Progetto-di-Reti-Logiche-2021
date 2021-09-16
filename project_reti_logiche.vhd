----------------------------------------------------------------------------------
-- Politecnico Di Milano
-- Fossati Stefano  (Matricola 910769)
-- Guggiari Sofia (Matricola 910391)
-- Progetto di Reti Logiche AA 2020/2021
-- Prof. Salice Fabio
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity project_reti_logiche is
    port(
        i_clk       : in std_logic ;
        i_rst       : in std_logic ;
        i_start     : in std_logic ;
        i_data      : in std_logic_vector (7 downto 0);
        o_address   : out std_logic_vector (15 downto 0);
        o_done      : out std_logic ;
        o_en        : out std_logic ;
        o_we        : out std_logic ;
        o_data      : out std_logic_vector (7 downto 0)
        );    
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is

    type state_type is(
        START,           -- 00 Stato iniziale della macchina
        READ_COL_REQ,    -- 01 Stato di caricamento dell'indirizzo di memoria delle colonne
        READ_COL,        -- 02 Stato della macchina in cui leggo il valore del numero di colonne
        READ_ROW_REQ,    -- 03 Stato di caricamento dell'indirizzo di memoria delle righe
        READ_ROW,        -- 04 Stato della macchina in cui leggo il valore del numero di righe
        START_FIND,      -- 05 Stato della macchina dove inizia la ricerca del valore minimo e massimo
        FIND_MIN_MAX,    -- 06 Stato di confronto per trovare massimo e minimo valore dell'immagine
        CALC_DELTA,      -- 07 Stato della macchina che calcola il delta value
        CALC_SHIFT,      -- 08 Stato della macchina che calcola il shift value
        START_EQ,        -- 09 Stato della macchina che inizializza l'equalizzazione dell'immagine
        LOAD_VALUE_EQ,   -- 10 Stato della macchina dove carico il valore del pixel da equalizzare
        SAVE_NEW_VALUE,  -- 11 Stato della macchina che salva il valore del pixel equalizzato nella mamoria
        DONE,            -- 12 Stato della macchina che porta a 1 il segnale o_done
        WAIT_START       -- 13 Stato della macchina che attende che il segnale i_start diventi 0
        );

    signal current_state, next_state : state_type;
    

begin
    state_reg: process(i_clk, i_rst)
    
    variable N_COL: integer;
    variable N_ROW: integer;
    variable MAX: integer range 0 to 255;
    variable MIN: integer range 0 to 255;
    variable COUNT: integer;
    variable TMP_COUNT: integer;
    variable VALUE: integer range 0 to 255;
    variable SHIFT_LEVEL: integer range 0 to 8;
    variable DELTA: integer range 0 to 255;
    variable DIMENSION: integer;
    variable TMP_VALUE: std_logic_vector(15 downto 0);
    
    begin
    
        if(i_rst = '1') then
            next_state <= START;
            current_state <= START;
            
        elsif(rising_edge(i_clk)) then
            current_state <= next_state;
            
            case current_state is
                    
                when START => 
                    o_done <= '0';
                    o_en <= '0';
                    o_we <= '0';
                    MAX := 0;
                    MIN := 255;
                    COUNT := 0;
                    if(i_start = '1') then
                        next_state <= READ_COL_REQ;
                    else
                        next_state <= START;
                    end if;
                
                when READ_COL_REQ =>
                    o_en <= '1';
                    o_we <= '0';
                    o_address <= "0000000000000000";
                    next_state <= READ_COL;
                    
                when READ_COL =>
                    N_COL := TO_INTEGER(unsigned(i_data));
                    next_state <= READ_ROW_REQ; 
                   
                when READ_ROW_REQ => 
                    o_en <= '1';
                    o_we <= '0';
                    o_address <= "0000000000000001";
                    next_state <= READ_ROW;
                    
                when READ_ROW => 
                    N_ROW := TO_INTEGER(unsigned(i_data));
                    DIMENSION := N_COL*N_ROW;
                    if(DIMENSION = 0) then
                       next_state <= DONE;
                    else
                       o_en <= '1';
                       o_we <= '0';
                       next_state <= START_FIND; 
                    end if;   
                     
                 when START_FIND =>
                    if(COUNT = DIMENSION) then
                        next_state <= CALC_DELTA;
                    elsif(COUNT < DIMENSION) then
                        o_address <= std_logic_vector(TO_UNSIGNED(2+COUNT, 16));  
                        TMP_COUNT := COUNT+1;
                        next_state <= FIND_MIN_MAX;
                    end if;
                
                 when FIND_MIN_MAX =>
                    VALUE := TO_INTEGER(unsigned(i_data));
                    if(MIN > VALUE) then
                        MIN := VALUE;
                    end if;
                    if(MAX < VALUE) then
                        MAX := VALUE;
                    end if;
                    COUNT := TMP_COUNT;
                    next_state <= START_FIND;
                    
                 when CALC_DELTA =>
                    DELTA := MAX - MIN;
                    COUNT := 0;
                    next_state <= CALC_SHIFT;
                    
                 when CALC_SHIFT =>
                    if(DELTA = 0) then
                        SHIFT_LEVEL := 8;
                    elsif(DELTA >= 1 AND DELTA < 3) then
                        SHIFT_LEVEL := 7;
                    elsif(DELTA >= 3 AND DELTA < 7) then
                        SHIFT_LEVEL := 6;
                    elsif(DELTA >= 7 AND DELTA < 15) then
                        SHIFT_LEVEL := 5;
                    elsif(DELTA >= 15 AND DELTA < 31) then
                        SHIFT_LEVEL := 4;
                    elsif(DELTA >= 31 AND DELTA < 63) then
                        SHIFT_LEVEL := 3;
                    elsif(DELTA >= 63 AND DELTA < 127) then
                        SHIFT_LEVEL := 2;
                    elsif(DELTA >= 127 AND DELTA < 255) then
                        SHIFT_LEVEL := 1;
                    elsif(DELTA = 255) then 
                        SHIFT_LEVEL := 0;
                    end if;
                    next_state <= START_EQ;
                    
                 when START_EQ => 
                    if(COUNT = DIMENSION) then
                        o_we <= '0';
                        o_en <= '0';
                        next_state <= DONE;
                    elsif(COUNT < DIMENSION) then
                        o_we <= '0';
                        o_address <= std_logic_vector(TO_UNSIGNED(2+COUNT, 16));  
                        TMP_COUNT := COUNT+1;
                        next_state <= LOAD_VALUE_EQ;
                    end if;
                    
                 when LOAD_VALUE_EQ =>
                    VALUE := TO_INTEGER(unsigned(i_data));
                    o_we <= '1';
                    o_address <= std_logic_vector(TO_UNSIGNED(2+COUNT+DIMENSION, 16));
                    TMP_VALUE := std_logic_vector(shift_left(unsigned(TO_UNSIGNED((VALUE-MIN),16)), SHIFT_LEVEL)); 
                    next_state <= SAVE_NEW_VALUE;
                     
                 when SAVE_NEW_VALUE =>
                    if(TO_INTEGER(unsigned(TMP_VALUE)) >= 255) then
                        o_data <= "11111111";
                    else
                        o_data <= TMP_VALUE(7 downto 0);
                    end if;
                    COUNT := TMP_COUNT;
                    next_state <= START_EQ;
                 
                 when DONE =>
                    o_done <= '1';
                    next_state <= WAIT_START;
                    
                 when WAIT_START =>
                    if(i_start = '0') then
                        next_state <= START;
                    else
                        next_state <= WAIT_START;
                    end if;
                       
            end case;    
        end if;
     end process;
     
     
end Behavioral;
