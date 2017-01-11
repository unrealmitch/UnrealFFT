class camera3d{

	//Camera
	public float camera_x, camera_y, camera_z,	tmp_camera_x, tmp_camera_y;
	public float cen_camera_x, cen_camera_y, cen_camera_z;
	public float mouse_x3, mouse_y3;

	public float translate_x, translate_y, translate_z;
	public float translate_x_t, translate_y_t, translate_z_t;

	public float rotate_x, rotate_y, rotate_z; 
	public float rotate_x_t, rotate_y_t, rotate_z_t; 

	public boolean key_release = false;
	public camera3d(){

	}

	void setCamera(boolean mode_3D){
		if(mode_3D){
			lights();
			perspective();
			camera(camera_x, camera_y, camera_z , cen_camera_x , cen_camera_y, cen_camera_z, 0, 1, 0);

			translate(translate_x, translate_y, translate_z);
			rotateX(rotate_x);rotateY(rotate_y);rotateZ(rotate_z);
			config3d();

			mouseCam();
			keyboard();
		}else{
			surface.setTitle("UnrealFFT [2D]");
			ortho( -width/2, width/2, -height/2, height/2);
			camera(width/2, height/2, 700 , width/2 ,height/2, 0, 0, 1, 0);
		}
	}

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

	public void config3d(){
		String title = 	"[ C_X: "+ camera_x + " | C_Y:" + camera_y + " | C_Z:" + camera_z +
						" || P_X:" + cen_camera_x + " | P_Y:" + cen_camera_y + " | P_Z:" + cen_camera_z +
						" || T_X:" + translate_x  + " | T_Y:" + translate_y  + " | T_Z:" + translate_z  +
						" || R_X:" + rotate_x + " | R_Y:" + rotate_y + " | R_Z:" + rotate_z + " ]";

		surface.setTitle(title);
	}

	void keyReleased() {
		key_release = true;
		//camera_x = tmp_camera_x;
		//camera_y = tmp_camera_y;
	}

	void mouseWheel(MouseEvent event) {
		float e = event.getCount();
		if (keyPressed && key == CODED && keyCode == CONTROL)
			translate_z += e*50;
		if (keyPressed && key == CODED && keyCode == SHIFT)
			rotate_z += e/20;
	}

	void mouseCam(){
		if(mousePressed && mouseButton == RIGHT){
			cen_camera_x = (mouseX - width/2) * 3;
			cen_camera_y = (mouseY - height/2) * 3;
		}
	}

	void keyboard(){
		//3D - Control Camera
		if (keyPressed && key == CODED && keyCode == SHIFT){
			if(key_release){
				key_release = false;
				mouse_x3 = mouseX; mouse_y3 = mouseY;
				rotate_x_t = rotate_x; rotate_y_t = rotate_y;
			}else{
				rotate_y = rotate_y_t + (mouse_x3 - mouseX) / 1000 ; 
				rotate_x = rotate_x_t - (mouse_y3 - mouseY) / 1000 ;
			}
		}

		if (keyPressed && key == CODED && keyCode == CONTROL){
			if(key_release){
				key_release = false;
				mouse_x3 = mouseX; mouse_y3 = mouseY;
				translate_x_t = translate_x; translate_y_t = translate_y;
			}else{
				translate_x = translate_x_t - (mouse_x3 - mouseX)*2; 
				translate_y = translate_y_t - (mouse_y3 - mouseY)*2;
			}
		}

		if (keyPressed && key == CODED && keyCode == ALT){
			if(key_release){
				key_release = false;
				mouse_x3 = mouseX; mouse_y3 = mouseY;
				translate_z_t = translate_z;
			}else{
				translate_z = translate_z_t - (mouse_y3 - mouseY)*5; 
			}
		}

		if (keyPressed){
			switch (key){
				//Control Object 3D
				/*
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
				*/

				case '0': case '1': case '2': case '3': case '4':
				case '5': case '6': case '7': case '8': case '9':
				setView((int) (key - '0')); break;
			}
		}
	}

}