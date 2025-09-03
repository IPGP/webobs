#include <stdio.h>
#include <math.h>
#include <time.h>
#include <string.h>
#include <iostream>

using namespace std;

#define MAXLN 1000000
#define v(i,j) (v[(i) + PPL * (j)])
#define grd_N(i,j) (grd_N->v[(i) + (j)*grd_N->PPL])
#define l(i,j) (L->v[(i) + (j)*grd->PPL])
#define QUAD(x)	((x) * (x))
#define D2(A,B)	sqrt( QUAD((A).x-(B).x) + QUAD((A).y-(B).y))
#define gamma   0.7071067811865
#define grd_last_n(i,j) (grd_last_n->v[(i) + (j)*grd_last_n->PPL])
#define grd_n(i,j) (grd_n->v[(i) + (j)*grd_n->PPL])
#define grd_Lf(i,j) (grd_Lf->v[(i) + (j)*grd_Lf->PPL])


typedef struct {
	double x;
	double y;
	double z;
} Point3D;


/* returns the number of cpu-ticks in seconds that
 * have elapsed. (or the wall-clock time)
 */
double second(void)
{
  return ((double)((unsigned int)clock()))/CLOCKS_PER_SEC;

  /* note: on AIX and presumably many other 32bit systems, 
   * clock() has only a resolution of 10ms=0.01sec 
   */ 
}

int readline(FILE *fp,char *fline);
FILE* safe_file_open(const char* filename, const char* mode) {
    FILE* fp = fopen(filename, mode);
    if (!fp) {
        fprintf(stderr, "Error opening file: %s\n", filename);
        exit(EXIT_FAILURE);
    }
    return fp;
};


class Grid {
public:
    char nome_matrix[500];
    char nome_georef[500];

	// inizio campi che non possono essere toccati
	int PPL;		/* pixel per linea    */
	int NOL;		/* numero di linee    */
	double ox;		/* ascissa origine   lower left corner!   */
	double oy;		/* ordinata origine  lower left corner!   */
	float dx;		/* passo orizzontale  */
	float dy;		/* passo verticale    */

	float NO_DATA;

	float max;
	float min;

	float *v;		/* pointer to grid values*/


	int numero_pixels;

	FILE *input;

	Grid(char *filename);


	Grid(Grid *grd, int type=0);
						// type = 0 crea un grid vuoto delle stesse dimensioni
	                    // type >0 is not used in this version of the code

	void read_matrix();
	void write_matrix(char *nome);
	void read_asc_ArcView_header(FILE *input);
	void write_asc_ArcView_header(FILE *output);
	
	float get_value(double x, double y);
};

class Polyline {
public:
  int n;		       	/* numero di vertici della polilinea 	*/
  Point3D *pt;				/* puntatore al primo punto della poli..*/
  Polyline(Polyline *p, double dl);	    // crea una polyline densificando a dl
double ReturnLength();
} ;
		

void read_input_data(char *nome_file);
int grid_flow(Grid *H, Grid *L, int n_iter, double x_in, double y_in);


double rad2 = (float) 1.414213;
double invMrand = 1/(((float)RAND_MAX) /2);

double DH = 0;
double deposito_stat = 0.0;

char grid_file_name[200];


bool OUTPUT_GRID_DEP = false;
char L_grid_name[200];

bool OUTPUT_GRID_NEW_H   = false;
char new_h_grid_name[200];


bool ATTIVA_N_Lf_GRID = false;
char output_N_grid_name[200];
char output_Lf_grid_name[200];
Grid *grd_last_n;
Grid *grd_n;
Grid *grd_N;
Grid *grd_Lf;
int CURRENT_N; 

double  Lf     = 0;
int		ALGO   = 0;

Point3D p;
int n_iter;
int n_path = 1;
double PathLength, dLength;
double MaxPathLength = 10000000;

int DEP_FLAG    = 0;

Point3D pmin, pmax;
bool WRITE_LINE_SHAPE=false;

double profile_dx;
int max_pts_poly;
char line_shape_name[200];
Point3D *pts;
int n;

int main(int argc,char *argv[])
{

	double t1 =  second();

	pmin.x = 0;
	pmax.x = -1;

	read_input_data(argv[1]);

	int k = 0;


	// reading command lines parameters (optionals)
	while( ++k < argc ){
		if(argv[k][0]=='-') 
		{
			if((strstr(argv[k],"-input_point")!=NULL) )
			{
				p.x = atof(argv[++k]);
				p.y = atof(argv[++k]);
			}
			else if((strstr(argv[k],"-input_DEM")!=NULL) )
			{
				sprintf(grid_file_name,"%s", argv[++k]);
				fprintf(stderr,"input_DEM: %s\n", grid_file_name);
			}
			else if((strstr(argv[k],"-Lf")!=NULL) )   
			{
				Lf = atof(argv[++k]);		
			}
			else if((strstr(argv[k],"-n_path")!=NULL) )
			{
				n_path = atoi(argv[++k]);		
			}
			else if((strstr(argv[k],"-DH")!=NULL) )
			{
				DH = atof(argv[++k]);		
			}
			else if((strstr(argv[k],"-DEP_FLAG")!=NULL) )
			{
				DEP_FLAG = atoi(argv[++k]);		
			}
			else if((strstr(argv[k],"-rand_seed")!=NULL) )
			{
				int seed = atoi(argv[++k]);
				srand(seed);
			}
			else if((strstr(argv[k],"-L_grid_name")!=NULL) )
			{
				OUTPUT_GRID_DEP = true;	
				k++;
				strcpy(L_grid_name, argv[k]);		
				fprintf(stderr,"L_grid_name = %s\n",L_grid_name);
			}
			else if(strcmp(argv[k],"-write_profile") == 0 )
			{
				WRITE_LINE_SHAPE = true;
				k++;
				profile_dx = atof(argv[++k]);
				fprintf(stderr,"Profile dl =%lf\n",profile_dx);
			}
		}
	}



	if(WRITE_LINE_SHAPE)
	{
		strcpy(line_shape_name, "profile_00000.txt");
		max_pts_poly = 1000;
		pts = (Point3D *)malloc(max_pts_poly*sizeof(Point3D));
	}


	int i;
	Grid *grd;
	grd = new Grid(grid_file_name);

	Grid *L		= new Grid(grd);
	for(i=0;i< L->numero_pixels;i++) L->v[i]=0;

	if(ATTIVA_N_Lf_GRID)
	{
		grd_N 	= new Grid(grd);
		grd_Lf  = new Grid(grd);
		for(i=0;i< L->numero_pixels;i++)	
		{
			grd_N->v[i] =-9999;                     // inizialized to standard NO_DATA
			grd_Lf->v[i]=-9999;                     // inizialized to standard NO_DATA
		}
	}

	
	
    // main call - grid_flow
    if( ALGO == 0 )
	{
		for(CURRENT_N=0;CURRENT_N<n_path;CURRENT_N++)
		{
			grid_flow(grd, L, n_iter, p.x, p.y);
		}
	}
	else if( ALGO == 6 )  // specified Lf
	{
		if(Lf > 0)
		{
			MaxPathLength = Lf/grd->dx;

			fprintf(stderr, "Lf = %lf\nMax length = %lf\n",Lf,MaxPathLength);
			for(CURRENT_N=0;CURRENT_N<n_path;CURRENT_N++)
			{
				grid_flow(grd, L, n_iter, p.x, p.y);
			}

		}
	}
	fprintf(stdout,"\t\t\t\t -> flow routines:           %.2f seconds.\n",second()-t1); 



    // saving grids
	if(OUTPUT_GRID_DEP)
	{
		L->write_matrix(L_grid_name);
	}
	if(OUTPUT_GRID_NEW_H)
	{
		grd->write_matrix(new_h_grid_name);
	}
	if(ATTIVA_N_Lf_GRID)
	{
		grd_N->write_matrix(output_N_grid_name);
		grd_Lf->write_matrix(output_Lf_grid_name);
		fprintf(stderr,"%s\n%s\n",output_N_grid_name,output_Lf_grid_name);
	}
	
	
	if(WRITE_LINE_SHAPE){
		FILE *output=fopen(line_shape_name,"w");
		double slope,Len=0.0,l1,l2;
		
		

		//fprintf(output,"x\ty\tz\tL\tslope\n",180./3.1415*slope);
		for(k=0;k<n;k++)
		{
			pts[k].z = grd->get_value( pts[k].x, pts[k].y);
			//fprintf(output,"%lf\t",pts[k].x);
			//fprintf(output,"%lf\t",pts[k].y);
			//fprintf(output,"%lf\t",pts[k].z);
			if(k==0) Len= 0.;
			if(k>0) Len+= D2(pts[k],pts[k-1]);
			//fprintf(output,"%lf\t",Len);
			if(k>0 && k<n-1)
			{
				l1 = D2(pts[k],pts[k-1]);
				l2 = D2(pts[k],pts[k+1]);
				slope = atan2( pts[k+1].z - pts[k-1].z, l1+l2);
			}
			else if(k==0)
			{
				l2 = D2(pts[k],pts[k+1]);
				slope = atan2( pts[k+1].z - pts[k].z, l2);
			}
			else if(k==n-1)
			{
				l2 = D2(pts[k],pts[k-1]);
				slope = atan2( pts[k].z - pts[k-1].z, l2);
			}
			//fprintf(output,"%lf\n",-180./3.1415*slope);
		}

			// sampling at dl (that is profile_dx) along the polyline
		double L_polyline=0.;
		for(k=1;k<n;k++)  	L_polyline+= D2(pts[k-1],pts[k]);
		int n_pts_dl = (int)(L_polyline/profile_dx)+2;
		Point3D *pts_dl =  (Point3D *)malloc(n_pts_dl * sizeof(Point3D));
		double l=0., l_previous =0., l_next=0.;
		int current_n=0;
		pts_dl[0] = pts[0];
		current_n++;
		l = l+profile_dx;
	
		for(k=1;k<n;k++)
		{
			l_next     += D2(pts[k-1],pts[k]);
	
	
			while(l<l_next)
			{
				pts_dl[current_n].x = (l-l_previous)/(l_next-l_previous) *  (pts[k].x - pts[k-1].x ) + pts[k-1].x;
				pts_dl[current_n].y = (l-l_previous)/(l_next-l_previous) *  (pts[k].y - pts[k-1].y ) + pts[k-1].y;
				pts_dl[current_n].z = (l-l_previous)/(l_next-l_previous) *  (pts[k].z - pts[k-1].z ) + pts[k-1].z;
				current_n++;
				l+=profile_dx;
			}
			l_previous = l_next;
		}
		if(l < l_next*1.00000001)
		{
			pts_dl[current_n] = pts[n-1];
			current_n++;
		}
		n_pts_dl = current_n;
	
	    fprintf(output,"x\ty\tz\tL\tslope\n",180./3.1415*slope);
		for(k=0;k<n_pts_dl;k++)
		{
			//pts_dl[k].z = grd->get_value( pts_dl[k].x, pts_dl[k].y);
			fprintf(output,"%lf\t",pts_dl[k].x);
			fprintf(output,"%lf\t",pts_dl[k].y);
			fprintf(output,"%lf\t",pts_dl[k].z);
			if(k==0) Len= 0.;
			if(k>0) Len+= D2(pts_dl[k],pts_dl[k-1]);
			fprintf(output,"%lf\t",Len);
			if(k>0 && k<n-1)
			{
				l1 = D2(pts_dl[k],pts_dl[k-1]);
				l2 = D2(pts_dl[k],pts_dl[k+1]);
				slope = atan2( pts_dl[k+1].z - pts_dl[k-1].z, l1+l2);
			}
			else if(k==0)
			{
				l2 = D2(pts_dl[k],pts_dl[k+1]);
				slope = atan2( pts_dl[k+1].z - pts_dl[k].z, l2);
			}
			else if(k==n-1)
			{
				l2 = D2(pts_dl[k],pts_dl[k-1]);
				slope = atan2( pts_dl[k].z - pts_dl[k-1].z, l2);
			}
			fprintf(output,"%lf\n",-180./3.1415*slope);
		}
	}
	
	fprintf(stderr,"\nTotal elapsed time: %.2f seconds.\n",second()-t1);
}






void read_input_data(char *nome_file)    // reading parameters (paramenters already specified in the command line are optional)
{
	FILE *input_file = safe_file_open(nome_file,"r");
	int line_check = 0;
	char fline[300];
	char keyword[100];
	int i;
	
	while(line_check != EOF)
    {   
        line_check = readline(input_file, fline);       
		
        sscanf(fline,"%s", keyword);
        

		if(strcmp(keyword,"input_DEM") == 0 )
		{
			sscanf(fline,"%s%s", keyword, grid_file_name);
		}
		else if(strcmp(keyword,"Xorigine") == 0 )
		{
			sscanf(fline,"%s%lf", keyword, &(p.x));
		}
		else if(strcmp(keyword,"Yorigine") == 0 )
		{
			sscanf(fline,"%s%lf", keyword, &(p.y));
		}
		else if(strcmp(keyword,"MaxPathLength") == 0 )
		{
			sscanf(fline,"%s%lf", keyword, &MaxPathLength);
		}
		else if(strcmp(keyword,"n_iter_per_path") == 0 )
		{
			sscanf(fline,"%s%d", keyword, &n_iter);
		}
		else if(strcmp(keyword,"n_path") == 0 )
		{
			sscanf(fline,"%s%d", keyword, &n_path);
		}
		else if(strcmp(keyword,"DH") == 0 )
		{
			sscanf(fline,"%s%lf", keyword, &DH);
		}
		else if(strcmp(keyword,"static_Depos.") == 0 )
		{
			sscanf(fline,"%s%lf", keyword, &deposito_stat);
		}
		else if(strcmp(keyword,"output_L_grid_name") == 0 )
		{
			OUTPUT_GRID_DEP = true;
			sscanf(fline,"%s%s", keyword, L_grid_name);
		}
		else if(strcmp(keyword,"New_h_grid_name") == 0 )
		{
			OUTPUT_GRID_NEW_H = true;
			sscanf(fline,"%s%s", keyword, new_h_grid_name);
		}
		else if(strcmp(keyword,"Lf") == 0 )
		{
			sscanf(fline,"%s%lf", keyword, &Lf);
		}
		else if(strcmp(keyword,"DEP_FLAG") == 0 )
		{
			sscanf(fline,"%s%d", keyword, &DEP_FLAG);
		}
        else if(strcmp(keyword,"rand_seed") == 0 )
		{
			int seed;
			sscanf(fline,"%s%d", keyword, &seed);
			srand(seed);
		}
        else if(strcmp(keyword,"output_N_grid_name") == 0 )
		{
			ATTIVA_N_Lf_GRID = true;
			sscanf(fline,"%s%s", keyword, output_N_grid_name);
			fprintf(stderr,"#%s#\n",output_N_grid_name);
		}
       	else if(strcmp(keyword,"output_Lf_grid_name") == 0 )
		{
			ATTIVA_N_Lf_GRID = true;
			sscanf(fline,"%s%s", keyword, output_Lf_grid_name);
			fprintf(stderr,"#%s#\n",output_Lf_grid_name);
		}
       	else if(strcmp(keyword,"write_profile") == 0 )
		{
			WRITE_LINE_SHAPE = true;
			sscanf(fline,"%s%lf", keyword, &profile_dx);
			fprintf(stderr,"Profile dl =%lf\n",profile_dx);
		}
		else if(strcmp(keyword,"Algo") == 0 )
		{
			sscanf(fline,"%s%d", keyword, &ALGO);
			fprintf(stderr,"Algo:  %d\n",ALGO);
		}
	}
	fclose(input_file);
}


int grid_flow(Grid *grd, Grid *L, int n_iter, double x_in, double y_in)
{
	char type, dir, vdir;
	n = 0;

	int ix, iy, gx,gy;
	double x, y, a;
	double vx, vy;
	double maxg, grad;
	double m, m_cr;
	float h[10];
	double PathLength, dLength;
	int dep_count;


	Point3D p;

    //attenzione! aggiunto
	x_in += grd->dx*0.5;
	y_in += grd->dy*0.5;

	// inizializzazione

	ix = (int)((x_in - grd->ox)/grd->dx);
	iy = (int)((y_in - grd->oy)/grd->dy);
	x  = 0;
	y  = 0;
	type = 4;

	if(!(ix >1 && iy > 1 && ix < grd->PPL-2 && iy < grd->NOL-2) )//punto di partenza non valido!
	{
		return 0;
	}

	#define height(i,j) (grd->v[(i) + (j)*grd->PPL])


	h[0] = height(ix -1, iy +1);
	h[1] = height(ix   , iy +1);
	h[2] = height(ix +1, iy +1);
	h[3] = height(ix -1, iy   );
	h[4] = height(ix   , iy   );
	h[5] = height(ix +1, iy   );
	h[6] = height(ix -1, iy -1);
	h[7] = height(ix   , iy -1);
	h[8] = height(ix +1, iy -1);
 
	if(WRITE_LINE_SHAPE) {
		p.x = (x + ix) * grd->dx + grd->ox;
		p.y = (y + iy) * grd->dy + grd->oy;
		p.z = 0;
		pts[0].x = p.x;
		pts[0].y = p.y;
		pts[0].z = p.z;
	}
	

	PathLength = 0;
	dep_count = 0;
	bool diretto = false;
	if(!diretto)
	{
			h[9] = h[0]; h[0] = h[2]; h[2] = h[9];
			h[9] = h[3]; h[3] = h[5]; h[5] = h[9];
			h[9] = h[6]; h[6] = h[8]; h[8] = h[9];
	}


	while( (n++ < n_iter) && 
			(height(ix   , iy   ) != grd->NO_DATA) && (ix >1) && (iy > 1) && (ix < grd->PPL-2) && (iy < grd->NOL-2)
			&& ( PathLength < MaxPathLength) )
	{

		gx = -1;
		gy = -1;



		//flip (se possibile)
		if(type != 2)
		{
			if(diretto) 
			{
				if(type == 3)
				{
					x = 1-x;
					ix++;
					h[0] = h[1];
					h[3] = h[4];
					h[6] = h[7];
					
					h[1] = h[2];
					h[4] = h[5];
					h[7] = h[8];
					
					h[2] = (float)(height(ix +1, iy +1) + DH*(rand()*invMrand-0.5));
					h[5] = (float)(height(ix +1, iy   ) + DH*(rand()*invMrand-0.5));
					h[8] = (float)(height(ix +1, iy -1) + DH*(rand()*invMrand-0.5));
				}
				h[9] = h[0]; h[0] = h[2]; h[2] = h[9];
				h[9] = h[3]; h[3] = h[5]; h[5] = h[9];
				h[9] = h[6]; h[6] = h[8]; h[8] = h[9];
				diretto = !diretto;
			}
			else 
			{
				h[9] = h[0]; h[0] = h[2]; h[2] = h[9];
				h[9] = h[3]; h[3] = h[5]; h[5] = h[9];
				h[9] = h[6]; h[6] = h[8]; h[8] = h[9];
				if(type == 3)
				{
					x = 1-x;
					ix--;
					
					h[2] = h[1];
					h[5] = h[4];
					h[8] = h[7];
					
					h[1] = h[0];
					h[4] = h[3];
					h[7] = h[6];
					
					h[0] = (float)(height(ix -1, iy +1) + DH*(rand()*invMrand-0.5));
					h[3] = (float)(height(ix -1, iy   ) + DH*(rand()*invMrand-0.5));
					h[6] = (float)(height(ix -1, iy -1) + DH*(rand()*invMrand-0.5));
				}
				diretto = !diretto;
			}
		}
/**/		

		maxg = 0;
		dir = -1;


		/////////////////////////////////////////
		// C E N T R O
		/////////////////////////////////////////
		if(type == 4)
		{
			if( h[4]-h[1]  > maxg) 
			{
				dir =  0;
				maxg = h[4]-h[1];
			}
			if( h[4]-h[5]  > maxg) 
			{
				dir =  2;
				maxg = h[4]-h[5];
			}
			if( h[4]-h[7]  > maxg) 
			{
				dir =  6;
				maxg = h[4]-h[7];
			}
			if( h[4]-h[3]  > maxg) 
			{
				dir =  8;
				maxg = h[4]-h[3];
			}
			if( gamma * (h[4]-h[8])  > maxg) 
			{
				dir =  4;
				maxg = gamma * (h[4]-h[8]);
			}
			if( gamma * (h[4]-h[0])  > maxg) 
			{
				dir =  10;
				maxg = gamma * (h[4]-h[0]);
			}

			//NE
			vx = h[4]-h[5];
			vy = h[4]-h[1];
			if(vx>0 && vy >0)
			{
				grad = sqrt(QUAD(vx) + QUAD(vy));
				if( grad  > maxg) 
				{
					dir =  1;
					maxg = grad;
				}			
			}

			//E-SE
			vx = h[4]-h[5];
			vy = h[5]-h[8];
			if( vy >0 && vx > vy)
			{
				grad = sqrt(QUAD(vx) + QUAD(vy));
				if( grad  > maxg) 
				{
					dir =  3;
					maxg = grad;
				}			
			}

			//S-SE
			vx = h[7]-h[8];
			vy = h[4]-h[7];
			if( vx >0 && vy > vx)
			{
				grad = sqrt(QUAD(vx) + QUAD(vy));
				if( grad  > maxg) 
				{
					dir =  5;
					maxg = grad;
				}			
			}

			//SW
			vx = h[4]-h[3];
			vy = h[4]-h[7];
			if(vx>0 && vy >0)
			{
				grad = sqrt(QUAD(vx) + QUAD(vy));
				if( grad  > maxg) 
				{
					dir =  7;
					maxg = grad;
				}			
			}

			//W-NW
			vx = h[4]-h[3];
			vy = h[3]-h[0];
			if(vy > 0 && vx > vy)
			{
				grad = sqrt(QUAD(vx) + QUAD(vy));
				if( grad  > maxg) 
				{
					dir =  9;
					maxg = grad;
				}			
			}

			//N-NW
			vx = h[1]-h[0];
			vy = h[4]-h[1];
			if(vx > 0 && vy > vx)
			{
				grad = sqrt(QUAD(vx) + QUAD(vy));
				if( grad  > maxg) 
				{
					dir =  11;
					maxg = grad;
				}			
			}



			if(dir == 0)
			{
				type = 4;
				vdir = 0;
				dLength      = 1.;
				PathLength += dLength;
				l(ix,iy)    += (float)dLength;
				gx = ix;
				gy = iy;
			}
			else if(dir == 2)
			{
				type = 4;
				vdir = 2;
				dLength      = 1.;
				PathLength += dLength;
				if(diretto) l(ix  ,iy)  += (float)dLength;
				else        l(ix-1,iy)  += (float)dLength;  
				gx = ix;
				gy = iy;
			}
			else if(dir == 6)
			{
				type = 4;
				vdir = 4;
				dLength      = 1.;
				PathLength += dLength;
				l(ix,iy-1)  += (float)dLength;
				gx = ix;
				gy = iy-1;
			}
			else if(dir == 8)
			{
				type = 4;
				vdir = 6;
				dLength      = 1.;
				PathLength += dLength;
				if(diretto) l(ix-1,iy)  += (float)dLength;
				else        l(ix  ,iy)  += (float)dLength;  
			}
			else if(dir == 4)
			{
				type = 4;
				vdir = 3;
				dLength      = rad2;
				PathLength += dLength;
				if(diretto) l(ix  ,iy-1)  += (float)dLength;
				else        l(ix-1,iy-1)  += (float)dLength;
			}
			else if(dir == 10)
			{
				type = 4;
				vdir = 7;
				dLength      = rad2;
				PathLength += dLength;
				if(diretto)  l(ix-1,iy)  += (float)dLength;
				else         l(ix  ,iy)  += (float)dLength;
			}

			else if(dir == 1) //NE
			{
				type = 2;
				vdir = -1;
				
				vx = h[4]-h[5];
				vy = h[4]-h[1];

				a = 1/(vx +vy);
				x = a * vx;
				y = a * vy;

				dLength      = sqrt(x*x + y*y);
				PathLength += dLength;
				l(ix,iy)    += (float)dLength;
			}
						
			else if(dir == 3) //E-SE 
			{
				type = 1;
				vdir = 3;
				
				vx = h[4]-h[5];
				vy = h[5]-h[8];

				x = 0;
				y = 1 - vy/vx;

				dLength      = sqrt(1 + QUAD(1-y));
				PathLength += dLength;
				if(diretto)  l(ix  ,iy-1)  += (float)dLength;
				else         l(ix-1,iy-1)  += (float)dLength;
			}

			else if(dir == 5) //S-SE 
			{
				type = 3;
				vdir = 4;
				
				vx = h[7]-h[8];
				vy = h[4]-h[7];
				
				x = vx/vy;
				y = 0;

				dLength      = sqrt(x*x + 1);
				PathLength += dLength;
				if(diretto)   l(ix  ,iy-1)    += (float)dLength;
				else          l(ix-1,iy-1)  += (float)dLength;
				gx = ix;
				gy = iy-1;

			}

			else if(dir == 7) //SW 
			{
				type = 2;
				vdir = 5;
				
				vx = h[4]-h[3];
				vy = h[4]-h[7];

				a = 1/(vx +vy);
				x = a * vy;
				y = a * vx;

				dLength      = sqrt(QUAD(1-x) + QUAD(1-y));
				PathLength += dLength;
				if(diretto) l(ix-1,iy-1)  += (float)dLength;
				else        l(ix,iy-1)  += (float)dLength;     
			}

			else if(dir == 9) //W-NW 
			{
				type = 1;
				vdir = 6;
				
				vx = h[4]-h[3];
				vy = h[3]-h[0];
				
				x = 0;
//RIMPIAZZATO!	y = 1 - vy/vx;
				y = vy/vx;

				dLength      = sqrt(1 + y*y);
				PathLength += dLength;
				if(diretto)   l(ix-1,iy)  += (float)dLength;
				else          l(ix  ,iy)  += (float)dLength;
			}

			else if(dir == 11) //N-NW 
			{
				type = 3;
				vdir = 7;
				
				vx = h[1]-h[0];
				vy = h[4]-h[1];
				
				x = 1 - vx/vy;
				y = 0;

				dLength      = sqrt(1 + QUAD(1-x));
				PathLength += dLength;
				if(diretto)   l(ix-1,iy)  += (float)dLength;
				else          l(ix  ,iy)  += (float)dLength;
			}

		}

		/////////////////////////////////////////
		//   L A T O    O R I Z Z O N T A L E
		/////////////////////////////////////////
		else if(type == 3){
			
			if( h[4]-h[5]  > maxg) 
			{
				dir =  16;
				maxg = h[4]-h[5];
			} 
			else if(h[5]-h[4]  > maxg)
			{
				dir =  12;
				maxg = h[5]-h[4];
			}

			//S
			vx = h[4]-h[5];
			vy = h[5]-h[8];
			if( vy > 0 )
			{
				grad = sqrt(QUAD(vx) + QUAD(vy));
				if( grad  > maxg) 
				{
					dir =  -2;
					maxg = grad;
				}			
			}

			//N
			vx = h[4]-h[5];
			vy = h[4]-h[1];
			if( vy > 0 )
			{
				grad = sqrt(QUAD(vx) + QUAD(vy));
				if( grad  > maxg) 
				{
					dir =  -3;
					maxg = grad;
				}			
			}

			if(dir == 16)
			{
				type = 4;
				
				dLength      = 1-x;
				PathLength += dLength;
				if(diretto)  
				{
					l(ix,iy)      += (float)dLength;
					vdir = 2;
				}
				else 
				{
					l(ix-1,iy)    += (float)dLength; 
					vdir = 2;
				}
				x = 0;
				y = 0;				
			}
			else if(dir == 12)
			{
				type = 4;
				
				dLength      = x;
				PathLength += dLength;
				if(diretto)  
				{
					l(ix,iy)      += (float)dLength;
					vdir = -1;
				}
				else 
				{
					l(ix-1,iy)    += (float)dLength; 
					vdir = -1;
				}
				x = 0;
				y = 0;			
			}

			//S (fine det.)
			else if(dir == -2)
			{
				// !!!!!! x -> y    e  y -> x !!!!!!!!
				//vx = h[4]-h[5];
				//vy = h[5]-h[8];
				m    = (h[4]-h[5])/(h[5]-h[8]);
				m_cr = 1-x;

				if(m == m_cr)
				{
					type = 4;
					vdir = 3;
			
					dLength      = sqrt(x*x-2*x+2);
					PathLength  += dLength;

					x = 0;
					y = 0;
				}
				else if(m < m_cr)
				{
					type = 2;
					vdir = 4;

					y = x/(1-m);
					
					dLength      = sqrt(QUAD(y-x)+x*x);
					PathLength  += dLength;

					x = y;
					y = 1-y;
				}
				else if(m > m_cr)
				{
					type = 1;
					vdir = 3;
				
					y = (1-x)/m;

					dLength      = sqrt(QUAD(1-x) + y*y);
					PathLength  += dLength;
					
					x = 0;
					y = 1-y;
				}				
				if(diretto) 
				{
					l(ix,iy-1)      += (float)dLength;
					gx = ix;
					gy = iy-1;
				}
				else     
				{
					l(ix-1,iy-1)    += (float)dLength;
					gx = ix-1;
					gy = iy-1;
				}
			}

			//N (fine det.)
			else if(dir == -3)
			{
				// !!!!!! x -> y    e  y -> x !!!!!!!!
				//vx = h[4]-h[5];
				//vy = h[4]-h[1];
				m    = (h[4]-h[5])/(h[4]-h[1]);
				m_cr = -x;

				if(m == m_cr)
				{
					type = 4;
					vdir = 0;
			
					dLength      = sqrt(x*x+1);
					PathLength += dLength;

					x = 0;
					y = 0;
				}
				else if(m > m_cr)
				{
					type = 2;
					vdir = -1;
					
					y = (1-x)/(m+1);

					dLength      = sqrt( QUAD(1-y-x) + y*y);
					PathLength += dLength;

					x = 1 - y;
				}
				else if(m < m_cr)
				{
					type = 1;
					vdir = -1;
					
					y = - x / m;

					dLength      = sqrt( x*x + y*y);
					PathLength += dLength;

					x = 0;
				}
				if(diretto) 
				{
					l(ix,iy)      += (float)dLength;
					gx = ix;
					gy = iy;
				}
				else        
				{
					l(ix-1,iy)    += (float)dLength;
					gx = ix-1;
					gy = iy;
				}
			}
		}
		
		/////////////////////////////////////////
		//   L A T O    V E R T I C A L E
		/////////////////////////////////////////
		else if(type == 1){
			
			if( h[4]-h[1]  > maxg) 
			{
				dir =  20;
				maxg = h[4]-h[1];
			} 
			else if( h[1]-h[4]  > maxg) 
			{
				dir =  22;
				maxg = h[1]-h[4];
			}

			//E
			vx = h[4]-h[5];
			vy = h[4]-h[1];
			if( vx > 0 )
			{
				grad = sqrt(QUAD(vx) + QUAD(vy));
				if( grad  > maxg) 
				{
					dir =  21;
					maxg = grad;
				}			
			}

			//W
			vx = h[1]-h[0];
			vy = h[4]-h[1];
			if( vx > 0 )
			{
				grad = sqrt(QUAD(vx) + QUAD(vy));
				if( grad  > maxg) 
				{
					dir =  23;
					maxg = grad;
				}			
			}



			
			if(dir == 20)
			{
				type = 4;
				vdir = 0;
				
				dLength      = 1-y;
				PathLength  += dLength;
				l(ix,iy)    += (float)dLength;
				gx = ix;
				gy = iy;

				
				x = 0;
				y = 0;				
			}
			else if(dir == 22)
			{
				type = 4;
				vdir = -1;
				
				dLength      = y;
				PathLength += dLength;
				l(ix,iy)    += (float)dLength;
				gx = ix;
				gy = iy;

				
				x = 0;
				y = 0;			
			}

			//E (fine det.)
			else if(dir == 21)
			{
				//vx = h[4]-h[5];
				//vy = h[4]-h[1];
				m    = (h[4]-h[1])/(h[4]-h[5]);//= vy/vx
				m_cr = - y ;

				if(m == m_cr)
				{
					type = 4;
					vdir = 2;
			
					dLength      = sqrt(y*y+1);
					PathLength  += dLength;

					x = 0;
					y = 0;
				}
				else if(m < m_cr)
				{
					type = 3;
					vdir = -1;
			
					x = -y/m;

					dLength      = sqrt(y*y+x*x);
					PathLength  += dLength;

					y = 0;
				}
				else if(m > m_cr)
				{
					type = 2;
					vdir = -1;
			
					x = (1-y)/(m+1);

					dLength      = sqrt(QUAD(y+x-1)+x*x);
					PathLength  += dLength;

					y = 1-x;
				}
				if(diretto) {
					l(ix,iy)      += (float)dLength;
					gx = ix;
					gy = iy;
				}
				else   
				{
					l(ix-1,iy)    += (float)dLength;
					gx = ix-1;
					gy = iy;
				}
			}

			//W (fine det.)
			else if(dir == 23)
			{
				//vx = h[1]-h[0];
				//vy = h[4]-h[1];
				m    = (h[4]-h[1])/(h[1]-h[0]);//= vy/vx
				m_cr = 1 - y ;

				if(m == m_cr)
				{
					type = 4;
					vdir = 7;
			
					dLength      = sqrt(QUAD(1-y)+1);
					PathLength  += dLength;

					x = 0;
					y = 0;
				}
				else if(m < m_cr)
				{
					type = 2;
					vdir = 6;
			
					x = y/(1-m);

					dLength      = sqrt(QUAD(x-y)+x*x);
					PathLength  += dLength;

					y = x;
					x = 1-x;
				}
				else if(m > m_cr)
				{
					type = 3;
					vdir = 7;
			
					x = (1-y)/m;

					dLength      = sqrt(QUAD(1-y)+x*x);
					PathLength  += dLength;

					y = 0;
					x = 1-x;
				}
				if(diretto) 
				{
					l(ix-1,iy)  += (float)dLength;
					gx = ix-1;
					gy = iy;

				}
				else        
				{
					l(ix,iy)    += (float)dLength;
					gx = ix;
					gy = iy;
				}

			}
		}


		/////////////////////////////////////////
		//   L A T O    O B L I Q U O
		/////////////////////////////////////////
		else if(type == 2){
			
			if( gamma * (h[1]-h[5])  > maxg) 
			{
				dir =  26;
				maxg = gamma * (h[1]-h[5]);
			} 
			else if( gamma * (h[5]-h[1])  > maxg) 
			{
				dir =  24;
				maxg = gamma * (h[5]-h[1]);
			}
			
			//N
			vx = h[1]-h[2];
			vy = h[5]-h[2];
			if( vx + vy > 0 )
			{
				grad = sqrt(QUAD(vx) + QUAD(vy));
				if( grad  > maxg) 
				{
					dir =  25;
					maxg = grad;
				}			
			}
			
			//S
			vx = h[5]-h[4];
			vy = h[1]-h[4];
			if( vx + vy > 0 )
			{
				grad = sqrt(QUAD(vx) + QUAD(vy));
				if( grad  > maxg) 
				{
					dir =  27;
					maxg = grad;
				}			
			}
			
			
			
			if(dir == 26)
			{
				type = 4;
				vdir = 2;
				
				dLength      = sqrt(QUAD(1-x)+y*y);
				PathLength  += dLength;
				x = 0;
				y = 0;				
			}
			else if(dir == 24)
			{
				type = 4;
				vdir = 0;
				
				dLength      = sqrt(QUAD(1-y)+x*x);
				PathLength  += dLength;
				x = 0;
				y = 0;			
			}
			
			//N (fine det.)
			else if(dir == 25)
			{

				vx = h[1]-h[2];
				vy = h[5]-h[2];

				if(vy == (1-y)/(1-x) *vx)
				{
					type = 4;
					vdir = 1;

			
					dLength      = sqrt(QUAD(1-y)+QUAD(1-x));
					PathLength  += dLength;

					x = 0;
					y = 0;
				}
				else if(vy > (1-y)/(1-x) *vx)
				{
					type = 3;
					vdir = 0;

					m = vx/vy;

					x = m + x - m * y;

					dLength      = sqrt(QUAD(1-y)+QUAD(1-x-y));
					PathLength  += dLength;

					y = 0;
				}
				else if(vy < (1-y)/(1-x) *vx)
				{
					type = 1;
					vdir = 2;

					m = vy/vx;

					y = m + y - m * x;

					dLength      = sqrt(QUAD(1-x)+QUAD(1-x-y));
					PathLength  += dLength;

					x = 0;
				}
			}


			//S (fine det.)
			else if(dir == 27)
			{

				vx = h[5]-h[4];
				vy = h[1]-h[4];

				if(vx == (1-y)/(1-x) * vy)
				{
					type = 4;
					vdir = -1;

			
					dLength      = sqrt(x*x + y*y);
					PathLength  += dLength;

					x = 0;
					y = 0;
				}
				else if(vy < y/x *vx)
				{
					type = 1;
					vdir = -1;

					m = vy/vx;

					y = y - m * x;

					dLength      = sqrt(QUAD(x)+QUAD(1-x-y));
					PathLength  += dLength;

					x = 0;
				}
				else if(vx < (1-y)/(1-x) *vy)
				{
					type = 3;
					vdir = -1;

					m = vx/vy;

					x = m + y - m * x;

					dLength      = sqrt(QUAD(y)+QUAD(x-y));
					PathLength  += dLength;

					y = 0;
					x = 1-x;
				}
			}
			if(diretto) 
			{
				l(ix,iy)      += (float)dLength;
				gx = ix;
				gy = iy;
			}
			else        
			{
				l(ix-1,iy)    += (float)dLength;
				gx = ix-1;
				gy = iy;
			}

	}





		// trasposta se non diretto
		if(!diretto)
		{
			h[9] = h[0]; h[0] = h[2]; h[2] = h[9];
			h[9] = h[3]; h[3] = h[5]; h[5] = h[9];
			h[9] = h[6]; h[6] = h[8]; h[8] = h[9];
			if(vdir == 7) vdir = 1;
			else if(vdir == 1) vdir = 7;
			else if(vdir == 6) vdir = 2;
			else if(vdir == 2) vdir = 6;
			else if(vdir == 5) vdir = 3;
			else if(vdir == 3) vdir = 5;
		}


		if(dir == -1) {
			vdir   = -1;
			if(dep_count < DEP_FLAG)
			{
				h[0] = (float)(height(ix -1, iy +1)+ DH*(rand()*invMrand-0.5));
				h[1] = (float)(height(ix   , iy +1)+ DH*(rand()*invMrand-0.5));
				h[2] = (float)(height(ix +1, iy +1)+ DH*(rand()*invMrand-0.5));
				h[3] = (float)(height(ix -1, iy   )+ DH*(rand()*invMrand-0.5));
				h[4] = (float)(height(ix   , iy   )+ DH*(rand()*invMrand-0.5));
				h[5] = (float)(height(ix +1, iy   )+ DH*(rand()*invMrand-0.5));
				h[6] = (float)(height(ix -1, iy -1)+ DH*(rand()*invMrand-0.5));
				h[7] = (float)(height(ix   , iy -1)+ DH*(rand()*invMrand-0.5));
				h[8] = (float)(height(ix +1, iy -1)+ DH*(rand()*invMrand-0.5));			
				dep_count++;
			}
			else 
			{
				dep_count = 0;
				height(ix,iy) += (float)deposito_stat;
				h[4]          += (float)deposito_stat;
			}
		}


		

		if(vdir == 0)
		{
			iy++;

			h[6] = h[3];
			h[7] = h[4];
			h[8] = h[5];

			h[3] = h[0];
			h[4] = h[1];
			h[5] = h[2];

			h[0] = (float)(height(ix -1, iy +1) + DH*(rand()*invMrand-0.5));
			h[1] = (float)(height(ix   , iy +1) + DH*(rand()*invMrand-0.5));
			h[2] = (float)(height(ix +1, iy +1) + DH*(rand()*invMrand-0.5));
		}
		else if(vdir == 2)
		{
			ix++;

			h[0] = h[1];
			h[3] = h[4];
			h[6] = h[7];

			h[1] = h[2];
			h[4] = h[5];
			h[7] = h[8];

			h[2] = (float)(height(ix +1, iy +1) + DH*(rand()*invMrand-0.5));
			h[5] = (float)(height(ix +1, iy   ) + DH*(rand()*invMrand-0.5));
			h[8] = (float)(height(ix +1, iy -1) + DH*(rand()*invMrand-0.5));
		}
		else if(vdir == 4)
		{
			iy--;

			h[0] = h[3];
			h[1] = h[4];
			h[2] = h[5];

			h[3] = h[6];
			h[4] = h[7];
			h[5] = h[8];

			h[6] = (float)(height(ix -1, iy -1) + DH*(rand()*invMrand-0.5));
			h[7] = (float)(height(ix   , iy -1) + DH*(rand()*invMrand-0.5));
			h[8] = (float)(height(ix +1, iy -1) + DH*(rand()*invMrand-0.5));
		}
		else if(vdir == 6)
		{
			ix--;

			h[2] = h[1];
			h[5] = h[4];
			h[8] = h[7];

			h[1] = h[0];
			h[4] = h[3];
			h[7] = h[6];

			h[0] = (float)(height(ix -1, iy +1) + DH*(rand()*invMrand-0.5));
			h[3] = (float)(height(ix -1, iy   ) + DH*(rand()*invMrand-0.5));
			h[6] = (float)(height(ix -1, iy -1) + DH*(rand()*invMrand-0.5));
		}
		else if(vdir == 1)
		{
			ix++;
			iy++;

			h[6] = h[4];
			h[7] = h[5];
			h[3] = h[1];
			h[4] = h[2];
			
			h[0] = (float)(height(ix -1, iy +1) + DH*(rand()*invMrand-0.5));
			h[1] = (float)(height(ix   , iy +1) + DH*(rand()*invMrand-0.5));
			h[2] = (float)(height(ix +1, iy +1) + DH*(rand()*invMrand-0.5));
			h[5] = (float)(height(ix +1, iy   ) + DH*(rand()*invMrand-0.5));
			h[8] = (float)(height(ix +1, iy -1) + DH*(rand()*invMrand-0.5));
		}
		else if(vdir == 3)
		{
			ix++;
			iy--;

			h[0] = h[4];
			h[1] = h[5];
			h[3] = h[7];
			h[4] = h[8];
			
			h[2] = (float)(height(ix +1, iy +1) + DH*(rand()*invMrand-0.5));
			h[5] = (float)(height(ix +1, iy   ) + DH*(rand()*invMrand-0.5));
			h[6] = (float)(height(ix -1, iy -1) + DH*(rand()*invMrand-0.5));
			h[7] = (float)(height(ix   , iy -1) + DH*(rand()*invMrand-0.5));
			h[8] = (float)(height(ix +1, iy -1) + DH*(rand()*invMrand-0.5));
		}
		else if(vdir == 5)
		{
			ix--;
			iy--;

			h[1] = h[3];
			h[2] = h[4];
			h[4] = h[6];
			h[5] = h[7];
			
			h[0] = (float)(height(ix -1, iy +1) + DH*(rand()*invMrand-0.5));
			h[3] = (float)(height(ix -1, iy   ) + DH*(rand()*invMrand-0.5));
			h[6] = (float)(height(ix -1, iy -1) + DH*(rand()*invMrand-0.5));
			h[7] = (float)(height(ix   , iy -1) + DH*(rand()*invMrand-0.5));
			h[8] = (float)(height(ix +1, iy -1) + DH*(rand()*invMrand-0.5));
		}
		else if(vdir == 7)
		{
			ix--;
			iy++;

			h[7] = h[3];
			h[8] = h[4];
			h[4] = h[0];
			h[5] = h[1];
			
			h[0] = (float)(height(ix -1, iy +1) + DH*(rand()*invMrand-0.5));
			h[1] = (float)(height(ix   , iy +1) + DH*(rand()*invMrand-0.5));
			h[2] = (float)(height(ix +1, iy +1) + DH*(rand()*invMrand-0.5));
			h[3] = (float)(height(ix -1, iy   ) + DH*(rand()*invMrand-0.5));
			h[6] = (float)(height(ix -1, iy -1) + DH*(rand()*invMrand-0.5));
		}


		// trasposta se non diretto
		if(!diretto)
		{
			h[9] = h[0]; h[0] = h[2]; h[2] = h[9];
			h[9] = h[3]; h[3] = h[5]; h[5] = h[9];
			h[9] = h[6]; h[6] = h[8]; h[8] = h[9];
			if(vdir == 7) vdir = 1;
			else if(vdir == 1) vdir = 7;
			else if(vdir == 6) vdir = 2;
			else if(vdir == 2) vdir = 6;
			else if(vdir == 5) vdir = 3;
			else if(vdir == 3) vdir = 5;
			p.x = (-x + ix) * grd->dx + grd->ox;
			p.y = (y + iy) * grd->dy + grd->oy;
/* CANC */  gx = (int)(ix -x+0.5);
/* CANC */  gy = (int)(iy +y+0.5);
		}
		else
		{
			p.x = (x + ix) * grd->dx + grd->ox;
			p.y = (y + iy) * grd->dy + grd->oy;
/* CANC */  gx = (int)(ix +x+0.5);
/* CANC */  gy = (int)(iy +y+0.5);
		}

		if(WRITE_LINE_SHAPE)
		{
			if(max_pts_poly < n+1)
			{
				max_pts_poly += 1000;
				pts = (Point3D *) realloc(pts, max_pts_poly *sizeof(Point3D));
			}
			pts[n].x = p.x;
			pts[n].y = p.y;
			pts[n].z = p.z;
		}
		
		

	if( ATTIVA_N_Lf_GRID && gx != -1 && gy != -1 )
		{
			if( CURRENT_N < grd_N(gx,gy) || grd_N(gx,gy) == grd_N->NO_DATA ) 
				grd_N(gx,gy) = (float)(CURRENT_N+1) ;
			if( PathLength < grd_Lf(gx,gy) || grd_Lf(gx,gy) == grd_Lf->NO_DATA )
				grd_Lf(gx,gy) = (float)PathLength;
		}
	}

	PathLength *= grd->dx;
	
	

	return 1;
}


Grid::Grid(char *filename){
	double t1 = second();
	strcpy(nome_matrix, filename);
	strcpy(nome_georef, filename);


	read_matrix();

	numero_pixels = NOL*PPL;
	fprintf(stderr,"\t\t\t\t -> Grid loaded (%d x %d):            %.2f seconds.\n",PPL,NOL,second()-t1); 
}

void Grid::write_matrix(char *nome){
	FILE *output;
	double t1 = second();

    if(strstr(nome,".xyz")!=NULL){
		if((output=fopen(nome,"w"))==NULL){
			fprintf(stderr,"The file '%s' cannot be created...\n",nome);
			exit(0);
		}
		fprintf(stderr,"Writing %s ... ",nome);
		for(int j=NOL-1;j>=0;j--){
			for(int i=0;i<PPL;i++) if(v(i,j)!=NO_DATA)
			{
				fprintf(output,"%lf %lf %f\n",ox+(i+0.5)*dx,oy+(j+0.5)*dy, v(i,j));
			}
		}
		fprintf(stderr," done.\n");
		fclose(output);
	}
	else if(strstr(nome,".asc")!=NULL){
		if((output=fopen(nome,"w"))==NULL){
			fprintf(stderr,"The file '%s' cannot be created...\n",nome);
			exit(0);
		}
		fprintf(stderr,"Writing %s ... ",nome);
		write_asc_ArcView_header(output);
		for(int j=NOL-1;j>=0;j--){
			for(int i=0;i<PPL;i++) {
				if(v(i,j) != NO_DATA) fprintf(output,"%f ",v(i,j));
				else fprintf(output,"%.0f ", NO_DATA);   // This assumes that the No_data value is an integer. This line is just to save disk space.
			}
			fprintf(output,"\n");
		}
		fprintf(stderr," done.\n");
		fclose(output);
	}

	fprintf(stdout,"\t\t\t\t ... saving grid:             %.2f seconds.\n",second()-t1); 
}

Grid::Grid(Grid *grd, int type){

	if(type == 0){
		PPL     = grd->PPL;
		NOL     = grd->NOL;
		ox      = grd->ox;
		oy      = grd->oy;
		dx      = grd->dx;
		dy      = grd->dy;
		NO_DATA = grd->NO_DATA;
		numero_pixels = PPL * NOL;
		
		if(PPL!=0) v = (float *)malloc(NOL * PPL * sizeof(float));
		else v=NULL;
		fprintf(stderr,"Grid allocated.\n");
	}
	else 
	{
		fprintf(stderr,"Wrong Grid::Grid request.\n");
	}
}


void Grid::read_matrix(){
 FILE *input;
 int h,i,j;
 char *p;
 h=0;
 p=(char *)&h;
 fprintf(stderr,"Loading grid '%s'.\n",nome_matrix);
 max = min = 0;

     if(strstr(nome_matrix,".asc")!=NULL){
		if ((input=fopen(nome_matrix,"r")) == NULL) {
			fprintf(stderr,"Can't load input grid '%s'\n",nome_matrix);
			exit(1);
		}
		cout<<"Loading grid data:  "<<nome_matrix<<endl;
		
		char fline[100];
		
		// loading the header
		read_asc_ArcView_header(input);
		// allocating the memory
		v = (float *)malloc(NOL * PPL * sizeof(float));	 
		// loading the grid matrix
		for(int j=NOL-1;j>=0;j--){
			for(int i=0;i<PPL;i++) fscanf(input,"%f",&v(i,j));
			fscanf(input,"\n");
		}
		fclose(input);
		fprintf(stderr,"Matrix loaded...\n");
	}
	else
	{
		fprintf(stderr,"Invalid grid format for '%s' \n",nome_matrix);
	}
   
}


void Grid::write_asc_ArcView_header(FILE *output){
	fprintf(output,"ncols         %d\n",PPL);
	fprintf(output,"nrows         %d\n",NOL);
//	fprintf(output,"xllcorner     %lf\n",ox-dx/2);
//	fprintf(output,"yllcorner     %lf\n",oy-dx/2);
	fprintf(output,"xllcorner     %lf\n",ox);
	fprintf(output,"yllcorner     %lf\n",oy);
	fprintf(output,"cellsize      %.15lf\n",dx);
	fprintf(output,"NODATA_value  %.0f\n",NO_DATA);
}

void Grid::read_asc_ArcView_header(FILE *fp)
{
	char fline[MAXLN], keyword[MAXLN];
	char xtype=' ', ytype=' ';
	int i, hdrlines = 0;
	double value;

	/* read ARC-Info header */
    while(1)
    {   
        readline(fp, fline);       
        if(!isalpha(*fline) || *fline == '-' || *fline == ' ')
            break;       
        
        hdrlines++;
        sscanf(fline,"%s %lf", keyword, &value);
        //fprintf(stderr,"%s %lf\n", keyword, value);
        
		if(strcmp(keyword,"ncols") == 0 || strcmp(keyword,"NCOLS") == 0)
			PPL = (int)value;
		else if(strcmp(keyword,"nrows") == 0 || strcmp(keyword,"NROWS") == 0)
			NOL = (int)value;
		else if(strcmp(keyword,"xllcenter") == 0 || strcmp(keyword,"XLLCENTER") == 0)
		{
			xtype = 'c';
			ox = value;
		}
		else if(strcmp(keyword,"xllcorner") == 0 || strcmp(keyword,"XLLCORNER") == 0)
		{
			xtype = 'e';
			ox = value;
		}
		else if(strcmp(keyword,"yllcenter") == 0 || strcmp(keyword,"YLLCENTER") == 0)
		{
			ytype = 'c';
			oy = value;
		}
		else if(strcmp(keyword,"yllcorner") == 0 || strcmp(keyword,"YLLCORNER") == 0)
		{
			ytype = 'e';
			oy = value;
		}
		else if(strcmp(keyword,"cellsize") == 0 || strcmp(keyword,"CELLSIZE") == 0)
			dx = value;
		else if(strcmp(keyword,"nodata_value") == 0 || strcmp(keyword,"NODATA_VALUE") == 0 ||
			strcmp(keyword,"NODATA_value") == 0)
			NO_DATA = value;
    }
    //write_asc_ArcView_header(stderr);
	dy = dx;
    /* adjust g->ox and g->oy if necessary (we store center of reference cell) */
        //    if(ytype == 'e') oy = oy + dy/2;
 
	/* adjust g->ox and g->oy if necessary (we do NOT store center of reference cell but corners) */
    if(xtype == 'c') ox = ox - dx/2;
    if(ytype == 'c') oy = oy - dy/2;
    /* position file pointer for ARC-Info file to beginning of image data */
    rewind(fp);
    for(i=0; i<hdrlines; i++) readline(fp, fline);
	fprintf(stderr,"DEM header loaded.\n");
}

float Grid::get_value(double x, double y)
{
	int i,j;
	double lx, ly;
	i = floor((x - ox-dx*0.5)/dx);
	j = floor((y - oy-dx*0.5)/dy);
	lx = x - (ox + (i+0.5) * dx) ;
	ly = y - (oy + (j+0.5) * dy);
	lx = lx/dx;
	ly = ly/dy;

	if(  i>= 0  &&  j>= 0  &&  i<PPL-1 && j<NOL-1 ) 
	{
		if(v(i,j)!=NO_DATA && v(i,j+1) != NO_DATA && v(i+1,j) !=NO_DATA && v(i+1,j+1)!=NO_DATA )
		{
			return v(i,j)*(1-lx)*(1-ly)+v(i,j+1)*ly*(1-lx)+v(i+1,j)*lx*(1-ly)+ v(i+1,j+1)*ly*lx;
		}
		else return NO_DATA;
	}
	else return NO_DATA;
}



int readline(FILE *fp,char *fline)
{
  int i = 0, ch;

  for(i=0; i< MAXLN; i++)
  {
    ch = getc(fp);

    if(ch == EOF) { *(fline+i) = '\0'; return(EOF); }
    else          *(fline+i) = (char)ch;

    if((char)ch == '\n') { *(fline+i) = '\0'; return(0); }
    if((char)ch == 10) { *(fline+i) = '\0'; return(0); }
  }
  return 1;
}

FILE *safe_file_open(char *filename, char *mode)
{
	FILE *file_ptr;
    if((file_ptr   = fopen(filename,mode))==NULL){
		fprintf(stderr,"\n** safe_file_open **:Cannot open file: '%s'\n\n",filename);
		exit(0);
	}
	return file_ptr;
}

Polyline::Polyline(Polyline *p, double dl)
{
	double L = p-> ReturnLength();
	
	n = (int)(L/dl+2);
	
	pt = (Point3D *)malloc(n * sizeof(Point3D));

	double l=0, l_previous =0, l_next=0;
	int current_n=0;
	pt[0] = p->pt[0];
	current_n++;
	l = l+dl;

	for(int i=1;i<p->n;i++)
	{
		l_next     += D2(p->pt[i-1],p->pt[i]);


		while(l<l_next)
		{
			pt[current_n].x = (l-l_previous)/(l_next-l_previous) *  (p->pt[i].x - p->pt[i-1].x ) + p->pt[i-1].x;
			pt[current_n].y = (l-l_previous)/(l_next-l_previous) *  (p->pt[i].y - p->pt[i-1].y ) + p->pt[i-1].y;
			pt[current_n].z = (l-l_previous)/(l_next-l_previous) *  (p->pt[i].z - p->pt[i-1].z ) + p->pt[i-1].z;
			current_n++;
			l+=dl;
		}

		l_previous = l_next;
	}
	if(l < l_next*1.00000001) {
		pt[current_n] = p->pt[p->n-1];
		current_n++;
	}
	n = current_n;
}

double Polyline::ReturnLength()
{
	double l=0;
	for(int i=1;i<n;i++)  	l+= D2(pt[i-1],pt[i]);
	return l;
}


