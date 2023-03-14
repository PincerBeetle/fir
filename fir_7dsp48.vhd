
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
use STD.textio.all;

entity fir_7dsp48 is
generic(
        INDATA_WIDTH     : integer range 1 to 25 := 16;
        OUTDATA_WIDTH    : integer range 1 to 43 := 16;
        TRUNCATION       : integer range 0 to 43:= 16;
        FILT_DEPTH       : integer := 64;
        CoefsFile        : string:="F:/works/_source/_fir/testcoef.data"
        );
port(
        clk_main         : in std_logic;
        indata_vld       : in std_logic;
        data_in          : in std_logic_vector(INDATA_WIDTH-1 downto 0);
        data_out         : out std_logic_vector(OUTDATA_WIDTH-1 downto 0);
        outdata_vld      : out std_logic
    );
        
end entity;

architecture filter of fir_7dsp48 is

component ADD_PRE_MULT_PRIM is
port
(
    product          : out std_logic_vector(47 downto 0);
    carryin          : in std_logic;
    clk              : in std_logic;
    ce               : in std_logic;
    load             : in std_logic;
    load_data        : in std_logic_vector(47 downto 0);
    multiplier       : in std_logic_vector(17 downto 0);
    preadd1          : in std_logic_vector(24 downto 0);
    preadd2          : in std_logic_vector(24 downto 0);
    rst              : in std_logic
);
end component;

type filter_coef_type is array (integer range 0 to FILT_DEPTH/2-1) of bit_vector(15 downto 0);--of integer range 0 to 2**14-1;
type filter_coef_type_std is array (integer range 0 to FILT_DEPTH/2-1) of std_logic_vector(15 downto 0);--of integer range 0 to 2**14-1;

impure function read_coef(file_name:string) return filter_coef_type_std is
    variable DataCoefLine           :line;
    file CoefFile :text open READ_MODE is file_name;
    variable coef_filter      :filter_coef_type;
    variable Result           :filter_coef_type_std;
    begin
        for i in filter_coef_type'range loop
            readline(CoefFile,DataCoefLine);
            read(DataCoefLine,coef_filter(i));
            Result(i):=To_StdLogicVector(coef_filter(i));
        end loop;
        return Result;
end function;

type filter_array is array (integer range 0 to FILT_DEPTH/2-1) of integer range -32768 TO 32767;
type preadd_type is array (integer range 0 to FILT_DEPTH/2-1) of std_logic_vector(24 downto 0);
type mult_type is array (integer range 0 to FILT_DEPTH/2-1) of std_logic_vector(17 downto 0);
type fout_type is array (integer range 0 to FILT_DEPTH/2-1) of std_logic_vector(47 downto 0);
type taps_type is array (integer range 0 to FILT_DEPTH-1) of std_logic_vector(INDATA_WIDTH-1 downto 0);
type taps_array is array (integer range 0 to 3*(FILT_DEPTH/2)-1) of std_logic_vector(INDATA_WIDTH-1 downto 0);
type taps_array2 is array (integer range 0 to FILT_DEPTH/2-1) of taps_array;

signal taps_reg         : taps_type;
signal reg_data_pre0    : taps_array2;
signal reg_data_pre1    : taps_array2;
signal preadd_in0       : taps_type;
signal preadd_in1       : taps_type;
signal preadder1        : preadd_type;
signal preadder2        : preadd_type;
signal multiplier       : mult_type;
signal load_data        : fout_type;
signal dsp_out          : fout_type;
signal enbl_reg         : std_logic_vector(2*(FILT_DEPTH-1)+7 downto 0);

attribute RAM_STYLE : string;
attribute RAM_STYLE of taps_reg: signal is "DISTRIBUTED";


signal COEF_FILT       :filter_coef_type_std:=read_coef(CoefsFile);

signal rst             : std_logic:='0';

begin

    load_data(0)<=(others=>'0');
    bus_data:for i in 0 to FILT_DEPTH/2-2 generate
        load_data(i+1)<=dsp_out(i);
    end generate bus_data;

    data_out<=std_logic_vector(resize(SHIFT_RIGHT(signed(dsp_out(FILT_DEPTH/2-1)(42 downto 0)),TRUNCATION),OUTDATA_WIDTH));

    signal_dsp:for i in 0 to FILT_DEPTH/2-1 generate 
        preadder1(i)<=std_logic_vector(resize(signed(preadd_in0(i)),25));
        preadder2(i)<=std_logic_vector(resize(signed(preadd_in1(i)),25));
        multiplier(i)<=std_logic_vector(resize(signed(COEF_FILT(i)),18));
    end generate signal_dsp;

    dsp_mod:for i in 0 to FILT_DEPTH/2-1 generate 

        dsp_prim:ADD_PRE_MULT_PRIM
        port map
        (
            product     =>      dsp_out(i),
            carryin     =>      '0',
            clk         =>      clk_main,
            ce          =>      '1',
            load        =>      '1',
            load_data   =>      load_data(i),
            multiplier  =>      multiplier(i),
            preadd1     =>      preadder1(i),
            preadd2     =>      preadder2(i),
            rst         =>      '0'
        );

    end generate dsp_mod;

    taps_proc:process (clk_main)
    begin
        if(rising_edge(clk_main)) then 
            taps_reg(0)<=data_in;
            for i in 0 to FILT_DEPTH-2 loop
                taps_reg(i+1)<=taps_reg(i);
            end loop;
        end if;
    end process;

    enbl_proc:process(clk_main)
    begin
        if(rising_edge(clk_main)) then
            enbl_reg(0)<=indata_vld;
            for i in 0 to 2*(FILT_DEPTH/2-1)+6 loop
                enbl_reg(i+1)<=enbl_reg(i);
            end loop;
            outdata_vld<=enbl_reg(2*(FILT_DEPTH/2-1)+7);
        end if;
    end process;

    delay_comp_proc:process(clk_main)

    begin
        if(rising_edge(clk_main)) then
            for j in 0 to FILT_DEPTH/2-1 loop
                reg_data_pre0(j)(0)<=taps_reg(j); 
                reg_data_pre1(j)(0)<=taps_reg(FILT_DEPTH-1-j); 

                for i in 0 to 2*(j+1)-1 loop
                    reg_data_pre0(j)(i+1)<=reg_data_pre0(j)(i); 
                    reg_data_pre1(j)(i+1)<=reg_data_pre1(j)(i); 
                end loop;

                preadd_in0(j)<=reg_data_pre0(j)(2*(j+1));
                preadd_in1(j)<=reg_data_pre1(j)(2*(j+1));
                    
            end loop;
        end if;
    end process;

end architecture;