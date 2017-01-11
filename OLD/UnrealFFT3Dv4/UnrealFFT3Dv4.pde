/*
	Proyect: 	Unreal FFT Equalizer
	Version:  	2.4
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

				2.4: Better 3D Camera Controll
					 Added wave fft form
					 Added beat (kick,snare,hat)
					 Better wifi/serial communication
					 Added background beat effect
*/

import processing.core.*;
import ddf.minim.analysis.*;
import ddf.minim.*;
import processing.serial.*;
import processing.net.*;

import java.io.*;
import java.net.*;

/********************************************************************************************************/
/********************************************************************************************************/

/* 												Variables												*/

/********************************************************************************************************/
/********************************************************************************************************/


//*** Constants ***\\\
	static int OCTAVE_DIV = 5;
	static boolean S_ENABLED = true;
	static int NUM_BANDS= OCTAVE_DIV*10;
	static String server = "192.168.1.15";

//*** AUDIO ***\\\
	FFT fftLog;
	Minim minim;
	AudioInput in;

	int buffer_size = 2048; 		//FFT size (frequency resolution)
	float sample_rate = 44100;

	//Audio Algorithm Variables\\
	
	//Bands [colorSpectrum]
	float[] bands_value = new float[OCTAVE_DIV*10];		//Value of a freq band
	float[] bands_max_value = new float[OCTAVE_DIV*10];	//Max value of a freq band [Effect Max Value]
	float band_max_abs = 100;							//Max value of all bands

	//BASS
	boolean bass_num_mode = true;	//mode of bass: TRUE: Max of all bars, FALSE: Mix (Avg) of all bars
	boolean bass_detected = false;	//Did a beat be detected?

	int bass_select_band = 0;		//First Freq Band that control the bass
	int bass_num_bands = 3;			//Num of bands since first to control the bass
	
	float bass_max = 60;			//Max level reached  for bass
	float bass_min = 60;			//Min level to detect a bass
	float bass_last = 0;			//The last level of bass
	float bass_amplitude = 0.9;		//Amplitude from bass_max to detect a beat bass
	
	int bass_times = 0;				//Times that a beat was detected

	int bass_attenuate_v = 100;		//Value to attenuate the color of the bass since was detected
	
	//BASS/SNARE/HAT
	BeatDetect beat;
	BeatListener beatL;
	float  kickSize, snareSize, hatSize;
	int  kickC = 0, snareC = 0, hatC = 0;
	boolean kickb = false;

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
	int mode_background = 0;	/* 0-> Beat 1->Static 2->Black */
	int mode_top_beat = 0;		/* 0-> Bass 1-> Beat */
	int mode_fft = 0;			/* 0-> FFT values 1-> FFT wave */

	//3D
	boolean mode_3D = false;
	float history_band_values[][];
	static int history_band_size = 360;
	int history_i = 0;
	float bars_z = 30;

	int figure_3d = 0;

	camera3d cam;

//*** SERIE ***\\\
	Serial s_port;
	int s_port_selected = -1;

//*** WLAN ***\\\
	Socket wServer;
	InetSocketAddress dirServer;
	PrintStream wServer_output;

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

	//Attenuate beat color
	long attenute_t = 0;
	long attenute_timer = 50;

	//Reduce max beat bass
	boolean bass_beat_reduce = true;
	long bass_beat_reduce_t;
	long bass_beat_reduce_timer_1 = 8000;
	long bass_beat_reduce_timer_2 = 200;
	float bass_beat_reduce_min = 100;

//*** Others ***\\\
	int key_release = 1;





class BeatListener implements AudioListener
{
	private BeatDetect beat;
	private AudioInput source;
 
	BeatListener(BeatDetect beat, AudioInput source)
	{
	this.source = source;
	this.source.addListener(this);
	this.beat = beat;
	}
 
	void samples(float[] samps)
	{
	beat.detect(source.mix);
	}
 
	void samples(float[] sampsL, float[] sampsR)
	{
	beat.detect(source.mix);
	}
}

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
	float x = 5; float y = height - 55;

	String[] text_gui = {"","","","",""};
	String[][] text_value = {{"AVG", "MAX"},
							 {"Random [BASS]", "Level [BASS]","0", "25", "50", "75", "100"}};

	fill(color(0,0,100,50));
	text_gui[0] = "A|Beat   ['M']: "+ text_value[0][booli(bass_num_mode)];
	text_gui[1] = "D|Alpha ['N']:  " + text_value[1][mode_alpha_bars];
	text_gui[2] = "D|Bars   ['B']:  " + mode_bars_color;
	text_gui[3] = "D|Mirror['V']:  " + mode_mirror_bars;
	text_gui[4] = "D|Background['F']:  " + mode_background;
	
	
	for(int i=0;i< text_gui.length;i++)
		text(text_gui[i],x,y+i*12);
}

void bass_attenuate(long time){
	if(attenute_t < time){
		if(bass_attenuate_v > 0 )bass_attenuate_v-=10; else bass_attenuate_v = 0; 
		attenute_t = time + attenute_timer;
		color_bg = color(hue(color_bass),saturation(color_bass), bass_attenuate_v);
	}
}
/************************************************/
/*												*/
/*					Audio FFT					*/
/*												*/
/************************************************/

void audio_wave(){

	float gain = 500;
	int tbase = 256;

	//float[] samples = in.mix.toArray();
	float[] samples = new float[in.bufferSize()];

	for (int i = 0; i < in.bufferSize(); ++i) {
		samples[i] = in.left.get(i);
	}

	int offset = 0;
	float maxdx = 0;

	for(int i = 0; i < samples.length/4; ++i){
		float dx = samples[i+1] - samples[i]; 
		if (dx > maxdx) {
			offset = i;
			maxdx = dx;
		}
	}

	

	int mylen = min(tbase, samples.length-offset);
	for(int i = 0; i < mylen - 1; i++){
		float x1 = map(i, 0, tbase, 0, width);
		float x2 = map(i+1, 0, tbase, 0, width);

		if(!mode_3D){
			stroke(color_bass);
			line(x1, height*0.85 - samples[i+offset]*gain, x2, height*0.85 - samples[i+1+offset]*gain);
			
			stroke(0);
			line(x1, height*0.85 - samples[i+offset]*gain-1, x2, height*0.85 - samples[i+1+offset]*gain-1);
			line(x1, height*0.85 - samples[i+offset]*gain+1, x2, height*0.85 - samples[i+1+offset]*gain+1);
		}
	}
}

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

		if(!mode_3D && mode_fft == 1){
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
	noStroke();
	//stroke(0);
	fill(color(hue(color_bass),100, 100, 100));
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
				bass_max = bass_min;
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
	int selectedBand = -1;

	if(!mode_3D) selectedBand = mouse_bars();

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
			//box(bars_w,10,bars_z*5);			//Max Band
			popMatrix();

			//box(bars_w,y,bars_z*5);		//Bar Band
			popMatrix();

			int history_j = history_i;

			for(int j = history_band_size-1; j>=0;j--){
			//for(int j = 0; j< history_band_size-1;j++){
				
				if(history_j < history_band_size-1)  history_j++; else history_j = 0;
				pushMatrix();
				
				if(figure_3d==0){
					//rotateX((float) j/100 *map(j,history_band_size,0,2,2));
					translate(bar_x_3,-history_band_values[history_j][i]/2,(-j-1)*bars_z);
					if(j == 0) {translate(0,0,2*bars_z); scale(1,1,3);}
				} else if(figure_3d == 1){
					rotateX(map(j, history_band_size, 0, -PI, PI));
					translate(bar_x_3,3*500-history_band_values[history_j][i]/2,0);
				}

				//if( i >= bass_select_band &&  i < bass_select_band + bass_num_bands){
				if( j == 0){ 
					//fill(color(0,0,100,alpha-map(j,0, history_band_size, 0,alpha)));
					fill(color(0,0,100,100));
				}else{
					switch (mode_bars_color){
						case 0: fill(color(h,s,b,100)); break;
						case 1: fill(color(h,s,b,map(bands_value[i],0, band_max_abs, 0,70))); break;
						case 2: fill(color(map(history_band_values[history_j][i],40, band_max_abs, 70,-50),s,b,alpha)); break;
						case 3: fill(color(h,s,b,alpha-map(j,0, history_band_size, 0,alpha)));
					}
				}
				

				box(bars_w,history_band_values[history_j][i],bars_z);
				popMatrix();

			}

			bar_x_3+=bars_w;

		//2D
		} else {
			float x = i*(bars_w)+bars_x;

			//MaxBar of band
			rect(x, bars_y-audio_bar_rescale(bar_max_y), bars_w, 2);

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

	switch(mode_alpha_bars){
		case 1: alpha = map(bass_sum/3, 0,400, 0, 255); break;
		case 2: alpha = 0; break;
		case 3: alpha = 25; break;
		case 4: alpha = 50; break;
		case 5: alpha = 75; break;
		case 6: alpha = 100; break;
	}

	if(mode_3D){

	fill(color(hue(color_bass),100, 100, map(bass_sum,0,bass_max,0,100)));
		pushMatrix();
			if(figure_3d == 0) translate(0,-pos_bass_circle_y*8,0);
			//sphere(bass_sum);
		popMatrix();
	}else{
		fill(color_bass);
		//fill(color(hue(color_bass),100, 100, 100));
		stroke(0);
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

float audio_bass(long time){

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
			bass_detected = true;
			bass_attenuate_v = 100;
			bass_times++;

			bass_beat_reduce_t = time + bass_beat_reduce_timer_1;
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
		if(bass_beat_reduce)
			text("BASS Red:    " + (bass_beat_reduce_t - time), text_start_x, text_start_y + 60);
		else
			text("BASS Red:   Activate ['q']" , text_start_x, text_start_y + 60);
	}		


	return bass_value;
}

void audio_bass_reduce(long time){
	if(bass_beat_reduce){
		if(bass_beat_reduce_t < time){
			if(bass_max > bass_beat_reduce_min) 
				bass_max -= 1;

			bass_beat_reduce_t = time + bass_beat_reduce_timer_2;
		}
	}
}

boolean audio_beat(){
	if ( beat.isKick() && !kickb){
	 kickSize = 100;
	 kickC++;
	 kickb = true;
	} else kickb = false;
	if ( beat.isSnare() ){
		snareSize = 100;
		snareC++;
	}
	if ( beat.isHat() ) {
		hatSize = 100;
		hatC++;
	}

	stroke(0);
	fill(0,100,100);
	ellipse(width/4*2, pos_bass_circle_y , kickSize, kickSize);
	fill(70,100,100); 
	ellipse(width/4, pos_bass_circle_y, snareSize, snareSize);
	fill(20,100,100); 
	ellipse(width/4*3, pos_bass_circle_y, hatSize, hatSize);
 
	kickSize = constrain(kickSize * 0.9, 16, 100);
	snareSize = constrain(snareSize * 0.9, 16, 100);
	hatSize = constrain(hatSize * 0.9, 16, 100);

	if(!mode_3D){
		fill(color(0,0,100,50));
		text("Bass:  " + kickC, text_start_x + 350, text_start_y);
		text("Snare: " + snareC, text_start_x + 350, text_start_y + 12);
		text("Hat:  " + hatC, text_start_x + 350, text_start_y + 24);
	}

	return beat.isKick();
}

/************************************************/
/*												*/
/*						WIFI					*/
/*												*/
/************************************************/

boolean connectWifi(){
	try{
		wServer = new Socket();
		dirServer = new InetSocketAddress(server, 80);
		wServer.connect(dirServer, 1000);
		wServer_output = new PrintStream(wServer.getOutputStream());
		wServer.setKeepAlive(true);
	}catch (UnknownHostException e){
		println(e);
		return false;
	}
	catch (IOException e){
		println(e);
		return false;
	}

	return true;
}
void sendWifi(long now){

	if(wServer.isConnected() && s_port_selected < 0){
		int lvl_output = (char) map(fft_sum,0,fft_max,0,256);

		
		if(wifi_package_t < now){

			color color_5050;
			switch(mode_background){
				case 0: color_5050 = color_bg;break;
				case 1: color_5050 = color_bass; break;
				case 2: color_5050 = color(0,0,0); break;
				default:  color_5050 = color_bg;break;
			}
						
			String output = "[" + lvl_output + ";" + 
			(int) map(red(color_5050), 0 , 360 ,0 ,255)+";"+
			(int) map(green(color_5050), 0 ,360 ,0 ,255)+";"+
			(int) map(blue(color_5050), 0 ,360 ,0 ,255)+";]\r\n" ;
			wifi_package_t = now + wifi_package_timer;
			wServer_output.print(output);
		}
		

		/*
		if(bass_detected == true){
			//String output = "[" + lvl_output + ";" + random(0,255)+";"+random(0,255)+";"+random(0,255)+";]\r\n" ;
			String output = "[" + lvl_output + ";" + 
				map(red(color_bass), 0 ,360 ,0 ,255)+";"+
				map(green(color_bass), 0 ,360 ,0 ,255)+";"+
				map(blue(color_bass), 0 ,360 ,0 ,255)+";]\r\n" ;
			wServer_output.print((int) output);
			wServer_output.print((int) output);
			wServer_output.print((int) output);
		}else if(wifi_package_t < now && false){
			//String output = "[" + lvl_output + ";-1;-1;-1;]\r\n" ;
			String output = "[" + lvl_output + ";" + 
				map(red(color_bass), 0 ,360 ,0 ,255)+";"+
				map(green(color_bass), 0 ,360 ,0 ,255)+";"+
				map(blue(color_bass), 0 ,360 ,0 ,255)+";]\r\n" ;
			wServer_output.print(output);
			wifi_package_t = now + wifi_package_timer;
		}
		*/

		fill(color(36,100,100,80)); 
	}else {
		fill(color(0,100,100,80));
	}

	if (!mode_3D) text("Server['C']: "+ server, width - 125, height-5);
	
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
						color color_5050;
						switch(mode_background){
							case 0: color_5050 = color_bg;break;
							case 1: color_5050 = color_bass; break;
							case 2: color_5050 = color(0,0,0); break;
							default:  color_5050 = color_bg;break;
						}
						s_port.write((char) (red(color_5050)*1.24));
						s_port.write((char) (green(color_5050)*1.24));
						s_port.write((char) (blue(color_5050)*1.24));
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
	if(S_ENABLED  && !mode_3D){
		int n_serie = Serial.list().length;
		float x = width - 50, y = height - 16*(n_serie) - 20;

		if(n_serie > 0){
			text("Arduino:", x, y);
			for(int i = 0; i < n_serie;i++){
				y+=16;
				if(mouseX >= x && mouseY >= y-16 & mouseY <= y){
					fill(color(36,100,100,80));
					if (mousePressed ){
						s_port_selected = i;
						if(s_port != null) s_port.stop();
						try {
						    s_port=new Serial(this,Serial.list()[i],115200);
						} catch (RuntimeException e) {
						   	println("Error: Busy Port -> " + i);
						    s_port = null;
						    s_port_selected = -1;
						}
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
/*					Keyboard					*/
/*												*/
/************************************************/

void keyReleased() {
	key_release = 1;
	cam.keyReleased();
}

void keyboard(long now){
	if (keyPressed){
		switch (key){
			//3D
			case 'f':if(key_release == 1) { if(figure_3d == 1) figure_3d = 0; else figure_3d++; key_release=0;} break;

			//Control Audio Algorithm
			case 'r' : bass_max = bass_min; fft_max = 0;  band_max_abs = 80; break;
			case 'm': if(key_release == 1) { if(bass_num_mode) bass_num_mode = false; else bass_num_mode = true; key_release = 0;}break;
			case 'q': if(key_release == 1) { if(bass_beat_reduce) bass_beat_reduce = false; else bass_beat_reduce = true; key_release = 0;}break;

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
				if(mode_3D){ mode_3D = false; camera(width/2, height/8, 2000 , width/2 , height/2, 0, 0, 1, 0);}
				else mode_3D = true; key_release = 0;}break;
			case 'n': if(key_release == 1){ if(mode_alpha_bars == 6) mode_alpha_bars = 0; else mode_alpha_bars++; key_release = 0;} break;
			case 'b': if(key_release == 1){ if(mode_bars_color == 2) mode_bars_color = 0; else mode_bars_color++; key_release = 0;} break;
			case 'v': if(key_release == 1){ if(mode_mirror_bars == 3) mode_mirror_bars = 0; else mode_mirror_bars++; key_release = 0;} break;
			case 'c': if(key_release == 1){ s_port_selected = -1; connectWifi(); key_release = 0;} break;
			case 'g': if(key_release == 1){ if(mode_background == 2) mode_background = 0; else mode_background++; key_release = 0;} break;
			case '<': if(key_release == 1){ if(mode_top_beat == 1) mode_top_beat = 0; else mode_top_beat++; key_release = 0;} break;
			case '>': if(key_release == 1){ if(mode_fft == 1) mode_fft = 0; else mode_fft++; key_release = 0;} break;

			default: break;
		}
			
	}
}


void mouseWheel(MouseEvent event) {
	cam.mouseWheel(event);
}


/********************************************************************************************************/
/********************************************************************************************************/

/* 												Program													*/

/********************************************************************************************************/
/********************************************************************************************************/

void setup() {


	//*** Design ***\\\
	size(1200, 800, P3D);
	//fullScreen(P3D);

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

	beat = new BeatDetect(in.bufferSize(), in.sampleRate());
	beatL = new BeatListener(beat, in);
	beat.setSensitivity(250);

	//3D
	cam = new camera3d();

	history_band_values = new float [history_band_size][];

	for(int i = 0; i < history_band_size; i++){
		history_band_values[i] = new float[OCTAVE_DIV*10];
	}

	cam.resetCamera();
	cam.setView(0);

	//Serie Comunication
	if(S_ENABLED){
		if(Serial.list().length > 0){
			//s_port_selected = 0;
			//s_port=new Serial(this,Serial.list()[0],115200);
		}
	}

	//Wifi Comunication
	connectWifi();
}


void draw() {

	if(mode_background == 0)
		background(color_bg);
	else if(mode_background == 1)
		background(color_bass);
	else
		background(0);

	long now = millis();
	fftLog.forward(in.mix);
	
	if (mode_3D){
		cam.setCamera(true);
	}else{
		cam.setCamera(false);
		gui_config();
		checkSerial(now);
	}
	
	//Config
	keyboard(now);
	
	//Audio
	text_start_x = width - 450;
	bass_detected = false;

	audio_fft();
	audio_bars(now);
	audio_bass(now);
	audio_bass_reduce(now);
	if(mode_top_beat == 1) audio_beat();
	if(mode_fft == 0) audio_wave();

	bass_attenuate(now);
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

