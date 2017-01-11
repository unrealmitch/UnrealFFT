/*
	Proyect: 	Unreal FFT Equalizer
	Version:  	2.0
	Info:    	Audio Analizer [FFT] with GUI and differents effect, that it can
				communicate with arduino.

	Date:    	29/10/2016
	Author:  	UnrealMitch
	Mail:    	unrealmitch@gmail.com
	Web:    	https://github.com/unrealmitch
	License:  	GNU GPL (http://www.gnu.org/copyleft/gpl.html)

	Changelog:
				1.1: Added arduino communication [2 args]
					 Added mouse band selection
					 Added keyboard config

				1.2: Configure beat [Amplitude,Mode]
					 Added different color effects to bars and his configuration 
					 Arduino selection and auto-detection

				2.0: Added 3D (OpenGL)

*/

import processing.core.*;
import ddf.minim.analysis.*;
import ddf.minim.*;
import processing.serial.*;
import processing.net.*;

/********************************************************************************************************/
/********************************************************************************************************/

/* 												Variables												*/

/********************************************************************************************************/
/********************************************************************************************************/


//*** Constants ***\\\
	static int OCTAVE_DIV = 3;
	static boolean S_ENABLED = false;
	static int NUM_BANDS= OCTAVE_DIV*10;
	static String server = "192.168.1.132";

//*** AUDIO ***\\\
	FFT fftLog;
	Minim minim;
	AudioInput in;

	int buffer_size = 1024; 		// also sets FFT size (frequency resolution)
	float sample_rate = 44100;

	//Audio Algorithm Variables\\
	
	//Bands [colorSpectrum]
	float[] bands_value = new float[OCTAVE_DIV*10];
	float[] bands_max_value = new float[OCTAVE_DIV*10];
	float band_max_abs = 80;

	//BASS
	int bass_select_band = 0;
	int bass_num_bands = 3;
	boolean bass_num_mode = true;	//mode of bass: TRUE: Max of all bars, FALSE: Mix (Avg) of all bars

	float bass_max = 0;
	float bass_last = 0;
	float bass_amplitude = 0.9;
	char bass_detected = 0;
	int bass_times = 0;
	
	//Vu Metter
	float fft_sum = 0;
	float fft_max = 0;
	float fft_avg = 0;

//*** DESIGN ***\\\

	//Circle Bass
	float pos_bass_circle_y = 100;

	//Bars
	int bars_size,bars_w,bars_x,bars_y,bars_h;

	//Text
	int text_start_x = 5,
		text_start_y = 20;

	//Color
	color color_bg = color(0,0,0);
	color color_bass = color(200,0,0);
	float alpha = 50;

	//Config GUI
	int mode_alpha_bars = 0;	/* 0-> Change by bass beat - 1-> By bass level*/
	int mode_alpha_max = 200;	/* Max alpha random value */

	int mode_bars_color = 0;	/* n-> bar_mirror_[n] */
	int mode_mirror_bars = 0;	/* n-> bar_mirror_[n] */

	//3D
	boolean mode_3D = false;
	float history_band_values[][];
	static int history_band_size = 300;
	int history_i = 0;
	float bars_z = 30;

		//Camera
		float camera_x, camera_y, camera_z,	tmp_camera_x, tmp_camera_y;
		float cen_camera_x, cen_camera_y, cen_camera_z;
		float mouse_x3, mouse_y3;

		float translate_x, translate_y, translate_z;
		float rotate_x, rotate_y, rotate_z; 

//*** SERIE ***\\\
	Serial s_port;
	int s_port_selected = -1;

//*** WLAN ***\\\
	Client wServer;
	boolean wServer_state = false;

//*** Timers ***\\\
	//color_Spectrum - bar_max\\
	long[] bands_bar_max_t = new long[OCTAVE_DIV*10];
	long bands_bar_max_timer_1 = 300;
	long bands_bar_max_timer_2 = 10;
	float bands_bar_max_rest = 20;

	//input_keybaord
	long input_keyboard_t = 0;
	long input_keyboard_timer_1 = 400;
	long input_keyboard_timer_2 = 10;

	//Wifi
	long wifi_package_t = 0;
	long wifi_package_timer = 50;
//*** Others ***\\\
	int key_release = 1;


/********************************************************************************************************/
/********************************************************************************************************/

/* 												Functions												*/

/********************************************************************************************************/
/********************************************************************************************************/

boolean bool(int i){
	if (i == 0) return false; else return true;
}

int booli(boolean b){
	if(b==true) return 1; else return 0;
}

void bar_mirror_0(float x, float y, float w, float h, color c1, color c2) {
	noFill();
	for (float i=y; i<= y+h; i++) {
		float inter = map(i, y, y+h, 0, 1);
		color c = lerpColor(c1, c2, inter);
		stroke(c);
		line(x, i, x+w, i);
	}
}

void bar_mirror_1(float x, float y, float w, float h, float c, float s, float b, float a) {
	noFill();
	for (float i=y; i<= y+h; i++) {
		float inter = map(i, y, y+h, 1, 0);
		stroke(color(c,s,b,a*inter));
		line(x, i, x+w, i);
	}
}

void gui_config(){
	float x = 5; float y = height - 50;

	String[] text_gui = {"","","",""};
	String[][] text_value = {{"AVG", "MAX"},
							 {"BEAT", "BAND BEAT"}};

	fill(color(0,0,100,50));
	text_gui[0] = "A|Beat   ['m']: "+ text_value[0][booli(bass_num_mode)];
	text_gui[1] = "D|Alpha ['n']:  " + text_value[1][mode_alpha_bars];
	text_gui[2] = "D|Bars   ['b']:  " + mode_bars_color;
	text_gui[3] = "D|Mirror['v']:  " + mode_mirror_bars;
	
	
	for(int i=0;i< text_gui.length;i++)
		text(text_gui[i],x,y+i*12);
}

/************************************************/
/*												*/
/*					Audio FFT					*/
/*												*/
/************************************************/

void audio_fft(){

	int spectrumSize = fftLog.specSize();

	int fullSpec_x = width/2 - spectrumSize/2;
	int fullSpec_y = (int) (height/1.1);

	int selectedFrequency = 0;
	float spectrumScale = 4;

	fft_sum = 0;

	for(int i = 0; i < spectrumSize; i++){

		if ( i == mouseX-fullSpec_x){
			selectedFrequency = i;
			stroke(color(0,0,100));
		}else {
			stroke(color_bass);
		}

		if(!mode_3D){
			int line_x = fullSpec_x + i;
			line(line_x, fullSpec_y, line_x, fullSpec_y + fftLog.getBand(i)*i/10);
			line(line_x, fullSpec_y, line_x, fullSpec_y - fftLog.getBand(i)*spectrumScale);
		}

		fft_sum += fftLog.getBand(i);
	}

	fft_avg = fft_sum/spectrumSize;
	if(fft_sum > fft_max) fft_max = fft_sum;

	if(!mode_3D){
	//Ellpise lines [vu metter]
	fill(color_bass);noStroke();
	float fft_bar = map(fft_sum, 0,fft_max, 0, (width/2) - bars_w*2);
	rect(width/2,pos_bass_circle_y-5, fft_bar, 10);
	rect(width/2,pos_bass_circle_y-5, -fft_bar, 10);
	
	//Text
	fill(color(0,0,100,50));
	text("FFT Freq : " + fftLog.indexToFreq(selectedFrequency), text_start_x + 218, text_start_y);
	text("FFT Val  : " + fftLog.getBand(selectedFrequency), text_start_x + 218, text_start_y+12);
	text("FFT Sum : " + fft_sum, text_start_x + 218,  text_start_y + 24);
	text("FFT Max : " + fft_max, text_start_x + 218,  text_start_y + 36);
	text("FFT Avg  : " + fft_avg, text_start_x + 218,  text_start_y + 48);
	}

}

/************************************************/
/*												*/
/*					Audio Bars					*/
/*												*/
/************************************************/

int mouse_bars(){
	if(mouseY > 100 && mouseY < bars_y){
		if( (mouseX >= bars_x) && (mouseX < bars_x + bars_w*(NUM_BANDS)) ){
			int selectedBand =  (int) ((mouseX-bars_x) / bars_w);
			if (mousePressed ){
				int tmp_selected = selectedBand - (bass_num_bands/2);
				if(tmp_selected < 0) tmp_selected = 0;
				if(tmp_selected+bass_num_bands > NUM_BANDS-1) tmp_selected = NUM_BANDS-bass_num_bands;
				bass_max = 0;
				bass_select_band = tmp_selected;
			}
			return selectedBand;
		}
		return -1;
	}
	return -1;
}

float audio_bar_rescale(float value){
	return map(value, 0, band_max_abs, 0, bars_h);
}

float audio_bars_max(int bar, float value, long time){

	if( value >= bands_max_value[bar] ){
		bands_max_value[bar] = value;
		bands_bar_max_t[bar] = time + bands_bar_max_timer_1;
	} else {
		if(time >= bands_bar_max_t[bar]){
			bands_max_value[bar]-=bands_bar_max_rest;
			bands_bar_max_t[bar] = time + bands_bar_max_timer_2;
		}
	}
	return bands_max_value[bar];
}

void audio_bars(long t_now){

	

	bars_size = fftLog.avgSize();
	bars_w = width / (bars_size + 2);
	bars_x = width/2 - (bars_size*bars_w)/2;
	bars_y = height/2 + 80;
	bars_h = height/2;

	float spectrumSum = 0, bass_sum = 0;
	int selectedBand = mouse_bars();

	//3D
	float bar_x_3 = -(bars_size*bars_w)/2;
	float bar_w_3 = bars_w * 2;

	for(int i = 0; i < bars_size; i++) {

		//Audio Band Values
		bands_value[i] = sqrt(sqrt(fftLog.getAvg(i)))*150;
		history_band_values[history_i][i] = bands_value[i];
		if(bands_value[i] > band_max_abs) band_max_abs = bands_value[i];
		float bar_max_y = audio_bars_max(i,bands_value[i], t_now);

		//Design
		float y = audio_bar_rescale(bands_value[i]);
		float h = i * 100/bars_size; h -= 10; h = 100 - h;
		float s = 70;
		float b = bands_value[i]/3 * 100, a = 100;
		if (i == selectedBand && !mode_3D) s=0;
		stroke(color(h,s,b,50));

		switch (mode_bars_color){
			case 0: fill(color(h,s,b,alpha)); break;
			case 1: fill(color(h,s,b,map(bands_value[i],0, band_max_abs, 0,70))); break;
			case 2: fill(color(map(bands_value[i],40, band_max_abs, 70,-50),s,b,alpha)); break;
		}

		//3D
		if(mode_3D){
			noStroke();

			pushMatrix();
			translate(bar_x_3,-y/2,0);

			pushMatrix();
			translate(0,-bar_max_y,0);
			box(bars_w,10,20);			//Max Band
			popMatrix();

			//box(bars_w,y,bars_z);			//Bar Band
			popMatrix();

			int history_j = history_i;

			for(int j = history_band_size-1; j>=0;j--){
			//for(int j = 0; j< history_band_size-1;j++){
				pushMatrix();
				translate(bar_x_3,-history_band_values[history_j][i]/2,-j*bars_z);

				if( i >= bass_select_band &&  i < bass_select_band + bass_num_bands) 
					fill(color(0,0,100,alpha-map(j,0, history_band_size, 0,alpha)));
				else
					fill(color(h,s,b,alpha-map(j,0, history_band_size, 0,80)));

				box(bars_w,history_band_values[history_j][i],bars_z);
				popMatrix();

				if(history_j < history_band_size-1)  history_j++; else history_j = 0;
			}
			
			bar_x_3+=bars_w;

		//2D
		} else {
			float x = i*(bars_w)+bars_x;

			//MaxBar of band
			rect(x, bars_y-audio_bar_rescale(bar_max_y);, bars_w, 2);

			//Bar of band
			rect(x, bars_y-y, bars_w, y);
			switch (mode_mirror_bars){
				case 0: bar_mirror_1(x,bars_y, bars_w, y/2,h,s,b,alpha); break;
				case 1: bar_mirror_1(x,bars_y, bars_w, y/2,h,s,h/2,alpha); break;
				case 2: bar_mirror_1(x,bars_y, bars_w, y/2,h,s,h/2,100); break;
				case 3: bar_mirror_0(x,bars_y, bars_w, y/2,color(h,s,b,alpha), color(0,0,0,0)); break;
			}
		}

	}	//END for bars

	if(history_i < history_band_size-1) history_i++; else history_i=0;


	//Bass
	for(int i=0; i < bass_num_bands;i++)
		bass_sum += bands_max_value[bass_select_band+i];
	bass_sum/=bass_num_bands;

	if(mode_alpha_bars == 1) alpha = map(bass_sum/3, 0,400, 0, 255);
	
	fill(color_bass);
	if(mode_3D){
		pushMatrix();
			translate(0,-pos_bass_circle_y*8,0);
			sphere(bass_sum);
		popMatrix();
	}else{
		ellipse(width/2, pos_bass_circle_y, bass_sum/3, bass_sum/3);

		//Text of selected band by mouse
		fill(color(0,0,100,50));
		if(selectedBand==-1){
			text("Band: ND", text_start_x + 140, text_start_y);
		}else{
			text("Band: " + selectedBand, text_start_x + 127, text_start_y);
			text("Val  : " + bands_value[selectedBand], text_start_x + 127, text_start_y + 12);
			text("Max: " + bands_max_value[selectedBand], text_start_x + 127, text_start_y + 24);

		}
	}
}

float audio_bass(){

	float bass_value = 0;

	if (bass_num_mode){							//By Maximun band
		for(int i=0; i < bass_num_bands;i++)
			if(bands_max_value[bass_select_band+i] > bass_value) bass_value = bands_max_value[bass_select_band+i];
		stroke(color(0,0,100,100));
	}else{										//By Average of all bands
		for(int i=0; i < bass_num_bands;i++)
			bass_value += bands_max_value[bass_select_band+i];
		bass_value/=bass_num_bands;

		if(mode_3D){

		}else{
			stroke(color(0,0,100,100));
			rect((bass_select_band)*(bars_w)+bars_x, bars_y-audio_bar_rescale(bass_value), bars_w*bass_num_bands, 2);
			stroke(color(0,40,100,50));
		}
	}

	if(mode_3D){
	}else{
		rect((bass_select_band)*(bars_w)+bars_x, bars_y-audio_bar_rescale(bass_max) , bars_w*bass_num_bands, 0.5);
		rect((bass_select_band)*(bars_w)+bars_x, bars_y-audio_bar_rescale(bass_max*bass_amplitude), bars_w*bass_num_bands, 0.5);
	}

	if( bass_value > bass_max*bass_amplitude){
		if(bass_value > bass_last){

			color_bass = color(random(100),100,100, 255);
			if(mode_alpha_bars == 0) alpha = random(mode_alpha_max);

			if (bass_max < bass_value) bass_max = bass_value;
			bass_detected = 1;
			bass_times++;
		}
	}

	bass_last = bass_value;

	if(!mode_3D){
		fill(color(0,0,100,50));
		if (bass_num_bands == 1)
			text("BASS Band: " + bass_select_band, text_start_x, text_start_y);
		else{
			if(bass_num_mode)
				text("BASS Band: [" + bass_select_band + "-" + (bass_select_band+bass_num_bands-1) + "] MAX", text_start_x, text_start_y);
			else
				text("BASS Band: [" + bass_select_band + "-" + (bass_select_band+bass_num_bands-1) + "] AVG", text_start_x, text_start_y);
		}

		text("BASS Lvl:     " + bass_last, text_start_x, text_start_y + 12);
		text("BASS Max:  " + bass_max, text_start_x, text_start_y + 24);
		text("BASS Hits:   " + bass_times, text_start_x, text_start_y + 36);
		text("BASS Amp:  " + bass_amplitude, text_start_x, text_start_y + 48);
	}


	return bass_value;
}

/************************************************/
/*												*/
/*						WIFI					*/
/*												*/
/************************************************/

void sendWifi(long now){

	if(wifi_package_t < now && true){
		if(wServer.active()){
			int lvl_output = (char) map(fft_sum,0,fft_max,0,256);
			if(bass_detected == 2)
				wServer.write("[" + 0 + ";" + "-1;]\r\n");
			else if(bass_detected == 1){
				wServer.write("[" + 0 + ";" + 
								random(0,255)+";"+random(0,255)+";"+random(0,255)+";]\r\n");
				//wServer.stop();
				//wServer = new Client(this, server, 80);
			}
			wServer_state = true;
		}else{
			wServer_state = false;
		}
		wifi_package_t = now + wifi_package_timer;
	}

	if(wServer_state) 
		fill(color(36,100,100,80)); 
	else {
		if(mouseX >= width - 110 && mouseY >= height-10){
			fill(color(20,100,100,80));
			if (mousePressed ) wServer = new Client(this, server, 80);
		}else
			fill(color(0,100,100,80));
	}
	text("Server: "+ server, width - 110, height-5);

}

/************************************************/
/*												*/
/*						Serial					*/
/*												*/
/************************************************/

void sendSerial(){
	if(S_ENABLED){
		if(s_port_selected>=0){
			if(s_port.available() > 0){
				if(s_port.read() == 'B'){
					char lvl_output = (char) map(fft_sum,0,fft_max,0,127);
					s_port.write(lvl_output);
					s_port.write(bass_detected);
				}
			}
		}
	}
}

void sendSerial_msg(char arg1, char arg2){
	if(S_ENABLED){
		while(true){
			if(s_port_selected>=0){
				if(s_port.available() > 0){
					if(s_port.read() == 'B'){
						s_port.write(arg1);
						s_port.write(arg2);
						break;
					}
				}
			}
		}
	}
}

void checkSerial(long now){
	if(S_ENABLED){
		int n_serie = Serial.list().length;
		float x = width - 50, y = height - 16*(n_serie) - 10;

		if(n_serie > 0){
			text("Arduino:", x, y);
			for(int i = 0; i < n_serie;i++){
				y+=16;
				if(mouseX >= x && mouseY >= y-16 & mouseY <= y){
					fill(color(36,100,100,80));
					if (mousePressed ){
						s_port_selected = i;
						if(s_port != null )s_port.stop();
						s_port=new Serial(this,Serial.list()[i],115200);
					}
				}else fill(color(0,0,100,50));

				if (s_port_selected == i)
					text(Serial.list()[i]+ "<-", x, y);
				else
					text(Serial.list()[i], x, y);
			}
		}
	}
}


/************************************************/
/*												*/
/*						3D						*/
/*												*/
/************************************************/

void resetCamera(){
	tmp_camera_x = camera_x = width/2; 
	tmp_camera_y= camera_y = height/8; 
	camera_z = 2000;
	
	cen_camera_x = width/2; cen_camera_y = height/2; cen_camera_z = 0;

	translate_x = width/2; translate_y = height; translate_z = 0;
	rotate_x=0; rotate_y=0; rotate_z=0;
}

void setCamera(float[] args){
	tmp_camera_x = camera_x = args[0]; tmp_camera_y= camera_y = args[1]; camera_z = args[2];
	cen_camera_x =  args[3]; cen_camera_y = args[4]; cen_camera_z = args[5];
	translate_x = args[6]; translate_y = args[7]; translate_z = args[8];
	rotate_x=args[9]; rotate_y=args[10]; rotate_z=args[11];
}

void setView(int v){
	float[][] view = {	{width/2,height/8,2000,	width/2,height/2,0,	width/2,height,0 ,0,0,0},				//0- Original
						{width/2*4,-height/8,2000,	width/2,height/2,0,	width/2,height,1000 ,0,0,0},		//1-Little Prespective
						{width/2,-height*1.5,2000,	width/2,height/2,0,	width/2,height,600 ,0,0,0},			//2
						{width*1.2,-height/4,2000,	width/2,height/2,0,	width*1.3,height,-200 ,0,7.4,0},	//3
						{width/2,height/8,2400,	width/2-1000,height/2+300,200,	width/2,height,0 ,0,2,-0.1},//4
						{width/1.5,height/6,4000,	width/2,height/2,0,	width/3, 0,-2000 ,-0.1,-3.1,0},		//5
						{width/2,height/8,2400,	width/2+1200,height/2,0,	width/3,height,0 ,0,-2,0},	//6
						{-width*0.9,-height*1.5,2350,	width/2,height/2,0,	-width/6,height/4,-1300 , 0.1,-3.2,0},	//7
						{width/3.5,-height/1.1,2000,	width/2,height/2,500,	width/1.8,height,-1000 ,0,-3.3,0},	//8
						{width, -height,2350,	width/2,height/2,500,	width-100,height/2,-1000 ,0.1,-3.3,0}		//9
					};


	setCamera(view[v]);
}

void config3d(){
	String title = 	"[ C_X: "+ camera_x + " | C_Y:" + camera_y + " | C_Z:" + camera_z +
					" || P_X:" + cen_camera_x + " | P_Y:" + cen_camera_y + " | P_Z:" + cen_camera_z +
					" || T_X:" + translate_x  + " | T_Y:" + translate_y  + " | T_Z:" + translate_z  +
					" || R_X:" + rotate_x + " | R_Y:" + rotate_y + " | R_Z:" + rotate_z + " ]";

	surface.setTitle(title);
}


/************************************************/
/*												*/
/*					Keyboard					*/
/*												*/
/************************************************/

void keyReleased() {
	key_release = 1;
	camera_x = tmp_camera_x;
	camera_y = tmp_camera_y;
}
void keyboard(long now){

	//3D - Control Camera
	if (keyPressed && key == CODED && keyCode == SHIFT){
		if(key_release == 1){
			key_release = 0;
			mouse_x3 = mouseX; mouse_y3 = mouseY;
		}else{
			tmp_camera_x = camera_x += (mouse_x3 - mouseX) / 10 ; 
			tmp_camera_y = camera_y += (mouse_y3 - mouseY) / 10;
		}
	}

	if (keyPressed && key == CODED && keyCode == CONTROL){
		if(key_release == 1){
			key_release = 0;
			tmp_camera_x = camera_x;
			tmp_camera_y = camera_y;
			mouse_x3 = mouseX; mouse_y3 = mouseY;
		}else{
			camera_x = tmp_camera_x + (mouse_x3 - mouseX) * 3; 
			camera_y = tmp_camera_y + (mouse_y3 - mouseY) * 3;
		}
	}

	if (keyPressed && key == CODED && keyCode == ALT){
			cen_camera_x = (mouseX - width/2) * 3;
			cen_camera_y = (mouseY - height/2) * 3;
	}

	if (keyPressed){
		switch (key){
			//Control Object 3D
			case 'a': translate_x-= 100;break;
			case 'd': translate_x+= 100;break;
			case 'w': translate_y-=100;break;
			case 's': translate_y+=100;break;
			case 'q': translate_z+=100;break;
			case 'e': translate_z-=100;break;

			case 'l': rotate_y-= 0.1;break;
			case 'j': rotate_y+= 0.1;break;
			case 'i': rotate_x-=0.1;break;
			case 'k': rotate_x+=0.1;break;
			case 'u': rotate_z-=0.1;break;
			case 'o': rotate_z+=0.1;break;

			case '0': case '1': case '2': case '3': case '4':
			case '5': case '6': case '7': case '8': case '9':
			setView((int) (key - '0')); break;

			//Control Audio Algorithm
			case 'r' : bass_max = 0; fft_max = 0;  band_max_abs = 80; break;
			case 'm': if(key_release == 1) { if(bass_num_mode) bass_num_mode = false; else bass_num_mode = true; key_release = 0;}break;

			case '+': bass_amplitude-=0.001; break;
			case '-': if (bass_amplitude < 1) bass_amplitude+=0.001; else bass_amplitude = 1.0; break;
	
			case '.':
				if(key_release == 1){
					if(bass_select_band + bass_num_bands<fftLog.avgSize()) bass_num_bands+=1; 
					key_release = 0;
					input_keyboard_t = now+input_keyboard_timer_1;
				}else if(now > input_keyboard_t){
					if(bass_select_band + bass_num_bands<fftLog.avgSize()) bass_num_bands+=1;
					input_keyboard_t = now+input_keyboard_timer_2;
				}
				break;
			case ',': 
				if(key_release == 1){
					if(bass_num_bands>1) bass_num_bands-=1;
					key_release = 0;
					input_keyboard_t = now+input_keyboard_timer_1;
				}else if(now > input_keyboard_t){
					if(bass_num_bands>1) bass_num_bands-=1;
					input_keyboard_t = now+input_keyboard_timer_2;
				}
				break;

			case CODED:
				switch(keyCode){
					case UP: bass_max+=2; break;
					case DOWN: bass_max-=2; break;
					case LEFT: 
						if(key_release == 1){
							if(bass_select_band!=0) bass_select_band-=1;
							key_release = 0;
							input_keyboard_t = now+input_keyboard_timer_1;
						}else if(now > input_keyboard_t){
							if(bass_select_band!=0) bass_select_band-=1;
							input_keyboard_t = now+input_keyboard_timer_2;
						}
						break;
					case RIGHT: 
						if(key_release == 1){
							if(bass_select_band + bass_num_bands<fftLog.avgSize()) bass_select_band+=1;
							key_release = 0;
							input_keyboard_t = now+input_keyboard_timer_1;
						}else if(now > input_keyboard_t){
							if(bass_select_band + bass_num_bands<fftLog.avgSize()) bass_select_band+=1;
							input_keyboard_t = now+input_keyboard_timer_2;
						}
						break;
					default: break;
				}
			break;

			//Control Gui Design
			case 'x': if(key_release == 1){ 
				if(mode_3D){ mode_3D = false; setView(0); camera(camera_x, camera_y, camera_z , cen_camera_x , cen_camera_y, cen_camera_z, 0, 1, 0);}
				else mode_3D = true; key_release = 0;}break;
			case 'n': if(key_release == 1){ if(mode_alpha_bars == 1) mode_alpha_bars = 0; else mode_alpha_bars++; key_release = 0;} break;
			case 'b': if(key_release == 1){ if(mode_bars_color == 2) mode_bars_color = 0; else mode_bars_color++; key_release = 0;} break;
			case 'v': if(key_release == 1){ if(mode_mirror_bars == 3) mode_mirror_bars = 0; else mode_mirror_bars++; key_release = 0;} break;
			
			default: break;
		}
			
	}
}

void mouseWheel(MouseEvent event) {
  float e = event.getCount();
  camera_z += e*50;
}
/********************************************************************************************************/
/********************************************************************************************************/

/* 												Program													*/

/********************************************************************************************************/
/********************************************************************************************************/

void setup() {


	//*** Design ***\\\
	size(1200, 800, P3D);
	
	surface.setResizable(true);
	background(0);
	colorMode(HSB, 100);
	textSize(10);
	ellipseMode(CENTER);

	//*** AUDIO ***\\\
	minim = new Minim(this);
	in = minim.getLineIn(Minim.MONO,buffer_size,sample_rate);
	fftLog = new FFT(in.bufferSize(), in.sampleRate());
	fftLog.linAverages(30);
	fftLog.logAverages(22, OCTAVE_DIV);
	fftLog.window(FFT.HAMMING);

	//3D
	history_band_values = new float [history_band_size][];

	for(int i = 0; i < history_band_size; i++){
		history_band_values[i] = new float[OCTAVE_DIV*10];
	}

	//resetCamera();
	setView(0);

	//Serie Comunication
	if(S_ENABLED){
		if(Serial.list().length > 0){
			s_port_selected = 0;
			s_port=new Serial(this,Serial.list()[0],115200);
		}
	}

	//Wifi Comunication
	wServer = new Client(this, server, 80);
}


void draw() {
	background(color_bg);

	long now = millis();
	fftLog.forward(in.mix);
	
	if (mode_3D){
		//3D
		lights();
		perspective();
		camera(camera_x, camera_y, camera_z , cen_camera_x , cen_camera_y, cen_camera_z, 0, 1, 0);
		translate(translate_x, translate_y, translate_z);
		rotateX(rotate_x);rotateY(rotate_y);rotateZ(rotate_z);
		config3d();
	}else{
		surface.setTitle("UnrealFFT [2D]");
		ortho( -width/2, width/2, -height/2, height/2);
		//camera(width/2, height/2, 700 , width/2 ,height/2, 0, 0, 1, 0);
		gui_config();
		checkSerial(now);
	}
	
	
	//Config
	keyboard(now);
	
	//Audio
	text_start_x = width - 350;
	bass_detected = 0;
	audio_bars(now);
	audio_fft();
	audio_bass();

	sendSerial();
	sendWifi(now);
}

void stop()
{
	sendSerial_msg((char)0,(char)0);
	in.close();
	minim.stop();
	super.stop();
}

