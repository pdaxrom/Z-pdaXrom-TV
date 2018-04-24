library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity main is
    Port ( clk_ext			: in  STD_LOGIC;
           tvout	: out STD_LOGIC_VECTOR (5 downto 0)
		 );
end main;

architecture Behavioral of main is

	component pll is
		port (
			CLKI: in  std_logic; 
			CLKOP: out  std_logic; 
			CLKOS: out  std_logic; 
			CLKOS2: out  std_logic);
	end component;

	COMPONENT pal_video
	Port (clk				: in  std_logic;
			line_visible	: out std_logic;
			line_even		: out std_logic;
			sync				: out std_logic;
			color				: out std_logic_vector(5 downto 0));
	END COMPONENT;
    
	component pal_encoder is
   Port (clk			: in  STD_LOGIC;
			sync			: in  STD_LOGIC;
			line_visible: in  STD_LOGIC;
			line_even	: in  STD_LOGIC;
			color			: in  STD_LOGIC_VECTOR (5 downto 0);
			output		: out STD_LOGIC_VECTOR (5 downto 0));
	end component;
 
	signal clk8		: std_logic;
	signal clk64	: std_logic;

 	--Outputs
   signal line_visible : std_logic;
   signal line_even : std_logic;
   signal sync : std_logic;
   signal color : std_logic_vector(5 downto 0);
   signal output : std_logic_vector(5 downto 0);
	
   signal video_out: std_logic_vector(5 downto 0);
begin

	clocks_inst: pll port map(
		CLKI => clk_ext,
		CLKOS => clk64,
		CLKOS2 => clk8);

   video_inst: pal_video PORT MAP (
		clk => clk8,
		line_visible => line_visible,
		line_even => line_even,
		sync => sync,
		color => color
   );

	encoder_inst:	pal_encoder port map (
		clk => clk64,
		line_visible => line_visible,
		line_even => line_even,
		sync => sync,
		color => color,
		output => tvout
	);
	
end Behavioral;

