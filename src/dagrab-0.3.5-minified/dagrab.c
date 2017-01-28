/*
   DAGRAB - dumps digital audio from cdrom to riff wave files

   (C) 1998,1999 Marcello Urbani <murbani@libero.it>

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.   */
/*
 *
 * Changes:
 *
 * - Initial release 0.1
 *   02/10/98
 *
 * - Added some options and fixed a few bugs
 *   02/18/98
 *
 * - Added speed and rest time diagnostics for single track
 *   04/02/98 Sascha Schumann <sas@schell.de>
 *
 * - Added -m -e -s -p functions, extended track info
 *   04/05/98 Sascha Schumann <sas@schell.de>
 *
 * - release 0.2
 *   04/23/98
 *
 * - changed my e-mail address - the old one expired :(
 *   07/??/98
 *
 * - Added cddb support, switches -S and -N, plus -D -P and -H
 *   07/30/98
 * 
 * - release 0.3
 *   08/25/98
 * 
 * - fixed a few bugs, mostly fixed by various people that mailed me
 *   I apologize for the lateness of this release.
 * 
 * - release 0.3.1
 *   06/24/99
 * 
 * - changed my e-mail address - the old one is expired (I forgot 
 *   to do this in the previous release)
 * 
 * - changed the default CDDB address to a working one (www.cddb.com)
 * 
 * - release 0.3.2
 *   10/10/99
 *
 * - modern kernels need O_NONBLOCK set when opening the cdrom device.
 *   (1999-10-19 dsembr01@slug.louisville.edu)
 *
 * - better error reporting when some of the system calls, or other
 *   functions that set errno, fail.
 *   (1999-10-19 dsembr01@slug.louisville.edu)
 *
 * - changed the default CDDB address to a free one (freedb.freedb.org)
 *   as suggested by Darren Stuart Embry (dsembr01@slug.louisville.edu)
 *
 * - release 0.3.3
 *   22/10/99
 *
 *  - release 0.3.5 minified : removed the cddb-stuff, implemented
 *    support for skipping data tracks
 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <getopt.h>
#include <dirent.h>
#include <netdb.h>
#include <unistd.h>
#include <pwd.h>
#define __need_timeval   /* needed by glibc */
#include <time.h>
#include <linux/cdrom.h>
#ifdef USE_UCDROM
#include <linux/ucdrom.h>
#endif
#include <sys/vfs.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <netinet/in.h>
#define CDDEVICE "/dev/cdrom"
#define N_BUF 8
#define OVERLAP 3
#define KEYLEN 12
#define OFS 12
#define RETRYS 40
#define IFRAMESIZE (CD_FRAMESIZE_RAW/sizeof(int))
#define BLEN 255
#define D_MODE 0660
#define PROGNAME "dagrab"
#define VERSION "0.3.5 minified"

struct cd_trk_list{
	int min;
	int max;
	int *starts;
	char *types;
	char *cddb;		// complete cddb entry
	int cddb_size;
	char *gnr;		// category; NULL if not obtained via cddbp
};

typedef unsigned short Word;

struct Wavefile{
	char Rid[4];
	unsigned Rlen;	/*0x24+Dlen*/
	char Wid[4];
	char Fid[4];
	unsigned Flen;
	Word tag;
	Word channel;
	unsigned sample_rate;
	unsigned byte_rate;
	Word align;
	Word sample;
	char Did[4];
	unsigned Dlen;
};

static int cdrom_fd;
static char *progname;
static int opt_blocks=N_BUF;
static int opt_keylen=KEYLEN;
static int opt_overlap=OVERLAP;
static int opt_retrys=RETRYS;
static int opt_ofs=OFS;
static int opt_ibufsize=0;
static int opt_bufsize=0;
static int opt_bufstep=0;
static int opt_verbose=0;
static int opt_chmod = D_MODE;
static int opt_spchk=0;
static unsigned opt_srate = 44100;	// still unused
static int opt_mono=0;
static int retries=0;

// track.end-magic_pre_data_track_limit
// before the data track
struct Datatracks{
int track_start;
int byte_start;
} d_tracks;

static struct Datatracks new_dtracks(int t_start, int b_start){
   struct Datatracks ds={t_start, b_start};
   return ds;
};
static int magic_pre_data_track_limit = 11574;

struct Wavefile cd_newave(unsigned size)
{
	struct Wavefile dummy={{'R','I','F','F'},0x24+size,{'W','A','V','E'},
		{'f','m','t',' '},0x10,1,2,44100,4*44100,4,16,
		{'d','a','t','a'},size };
		/*dummy.Dlen=size;
		  dummy.Rlen=0x24+size;*/
		dummy.sample_rate = opt_srate;
		dummy.channel = 2 - opt_mono;
		dummy.byte_rate = opt_srate << dummy.channel;
		dummy.align = dummy.channel * dummy.sample >> 3;
		dummy.Dlen >>= opt_mono;
		return dummy;
}

char *resttime(int sec)
{
	static char buf[BLEN+1];
	snprintf(buf, BLEN, "%02d:%02d:%02d", sec/3600, (sec/60)%60, sec%60);
	return buf;
}

int cd_get_tochdr(struct cdrom_tochdr *Th)
{
	return ioctl(cdrom_fd,CDROMREADTOCHDR,Th);
}

int cd_get_tocentry(int trk,struct cdrom_tocentry *Te,int mode)
{
	Te->cdte_track=trk;
	Te->cdte_format=mode;
	return ioctl(cdrom_fd,CDROMREADTOCENTRY,Te);
}

void cd_read_audio(int lba,int num,char *buf)
	/* reads num CD_FRAMESIZE_RAW sized
	   sectors in buf, starting from lba*/
	/*NOTE: if num>CDROM_NBLOCKS_BUFFER as defined in ide_cd.c (8 in linux 2.0.32)
	  jitter correction may be required inside the block. */					   
{
	struct cdrom_read_audio ra;

	ra.addr.lba=lba;
	ra.addr_format=CDROM_LBA;
	ra.nframes=num;
	ra.buf=buf;
	if(ioctl(cdrom_fd,CDROMREADAUDIO,&ra)){
		/*fprintf(stderr,"%s: read raw ioctl failed \n",progname);*/
		fprintf(stderr,"\n%s: read raw ioctl failed at lba %d length %d: %s\n",
				progname,lba,num,strerror(errno));
		exit(1);
	}
}

int cd_getinfo(char *cd_dev,struct cd_trk_list *tl)
{
	int i;
	struct cdrom_tochdr Th;
	struct cdrom_tocentry Te;

	if ((cdrom_fd=open(cd_dev,O_RDONLY|O_NONBLOCK))==-1){
		fprintf(stderr,"%s: error opening device %s\n",progname,cd_dev);
		exit(1);
	}
	if(cd_get_tochdr(&Th)){
		fprintf(stderr,"%s: read TOC ioctl failed: %s\n",progname,strerror(errno));
		exit(1);
	}
	tl->min=Th.cdth_trk0;tl->max=Th.cdth_trk1;
	if((tl->starts=(int *)malloc((tl->max-tl->min+2)*sizeof(int)))==NULL){
		fprintf(stderr,"%s: list data allocation failed\n",progname);
		exit(1);
	}
	if((tl->types=(char *)malloc(tl->max-tl->min+2))==NULL){
		fprintf(stderr,"%s: list data allocation failed\n",progname);
		exit(1);
	}

	for (i=tl->min;i<=tl->max;i++)
	{
		if(cd_get_tocentry(i,&Te,CDROM_LBA)){
			fprintf(stderr,"%s: read TOC entry ioctl failed: %s\n",
				progname,strerror(errno));
			exit(1);
		}
		tl->starts[i-tl->min]=Te.cdte_addr.lba;
		tl->types[i-tl->min]=Te.cdte_ctrl&CDROM_DATA_TRACK;
	}
	i=CDROM_LEADOUT;
	if(cd_get_tocentry(i,&Te,CDROM_LBA)){
		fprintf(stderr,"%s: read TOC entry ioctl failed: %s\n",progname,strerror(errno));
		exit(1);
	}
	tl->starts[tl->max-tl->min+1]=Te.cdte_addr.lba;
	tl->types[tl->max-tl->min+1]=Te.cdte_ctrl&CDROM_DATA_TRACK;

	if(i==1) tl->gnr=NULL;
	return 0;
}

void cd_disp_TOC(struct cd_trk_list *tl, int disp_TOC)
{
	int i, len;

    if(disp_TOC){
        printf("%5s %8s %8s %5s %9s %4s","track","start","length","type",
                "duration", "MB");
    }

    if(disp_TOC){
	 printf("\n");
	}

    int lastTrackStop = 0;
	for (i=tl->min;i<=tl->max;i++)
	{
		len = tl->starts[i + 1 - tl->min] - tl->starts[i - tl->min];
		if(disp_TOC){
            printf("%5d %8d %8d %5s %9s %4d",i,
                tl->starts[i-tl->min]+CD_MSF_OFFSET, len,
                tl->types[i-tl->min]?"data":"audio",resttime(len / 75),
                (len * CD_FRAMESIZE_RAW) >> (20 + opt_mono));
         }

		// record the data tracks start!
		if(tl->types[i-tl->min]){
		   d_tracks = new_dtracks(i, lastTrackStop);
		}else {
		    lastTrackStop=((tl->starts[i-tl->min]+CD_MSF_OFFSET +len));
		}

		if(disp_TOC){
		   printf("\n");
		}
	}

   if(disp_TOC){
        printf("%5d %8d %8s %s\n",CDROM_LEADOUT,
                tl->starts[i-tl->min]+CD_MSF_OFFSET,"-","leadout");
	}
}
int cd_jc1(int *p1,int *p2) //nuova
	/* looks for offset in p1 where can find a subset of p2 */
{
	int *p,n;

	p=p1+opt_ibufsize-IFRAMESIZE-1;n=0;
	while(n<IFRAMESIZE*opt_overlap && *p==*--p)n++;
	if (n>=IFRAMESIZE*opt_overlap)	/* jitter correction is useless on silence */ 
	{
		n=(opt_bufstep)*CD_FRAMESIZE_RAW;
	}
	else			/* jitter correction */
	{
		n=0;p=p1+opt_ibufsize-opt_keylen/sizeof(int)-1;
		while((n<IFRAMESIZE*(1+opt_overlap)) && memcmp(p,p2,opt_keylen))
		  {p--;n++;};
/*		  {p-=6;n+=6;}; //should be more accurate, but doesn't work well*/
		if(n>=IFRAMESIZE*(1+opt_overlap)){		/* no match */
			return -1;
		};
		n=sizeof(int)*(p-p1);
	}
	return n;
}

int cd_jc(int *p1,int *p2)
{
	int n,d;
	n=0;
	do
		d=cd_jc1(p1,p2+n);
	while((d==-1)&&(n++<opt_ofs));n--;
	if (d==-1) return (d);
	else return (d-n*sizeof(int));
}

int check_for_space(char *path, int space)
{
	struct statfs buffs;
	struct stat buf;

	if(!stat(path, &buf) && !statfs(path, &buffs) &&
			(buffs.f_bavail * buf.st_blksize) >= space) return 1;
	return 0;
}

int cd_read_track(char *basename,int tn,struct cd_trk_list *tl,
		char *filter)
{
	int buf1[opt_ibufsize];		
	int buf2[opt_ibufsize];
	short buf3[opt_ibufsize];
	int *p1,*p2,*p;
	char nam[BLEN+1], exec[BLEN+1];
	struct Wavefile header;
	int fd,bytes,i,n,q,space;
	int bcount, sc, missing, speed = 0, ldp, now;
	int stop_jittering_mode=0;
	int readuntil;

    if(tl->starts[tn-tl->min]<0)
        tl->starts[tn-tl->min] = 0;

	if(tn<tl->min || tn>tl->max) return (-1);

	if(d_tracks.track_start>0 && tn==d_tracks.track_start-1){
	  printf("Entering a pre-DATA-track - we will avoid slipping into it..\n");
	  stop_jittering_mode=1;
	   readuntil=d_tracks.byte_start-magic_pre_data_track_limit;
	} else {
	   readuntil=tl->starts[tn-tl->min+1];
	}

	space = ((readuntil-tl->starts[tn-tl->min]) *
			CD_FRAMESIZE_RAW) >> opt_mono;
    snprintf(nam,BLEN,basename,tn);
	if(tl->types[tn-tl->min]){
		fprintf(stderr,"Track %d is not an audio track\n",tn);
		return 1;
	}
	else printf("Dumping track %d: lba%7d to lba%7d (needs %d MB)\n",tn,
			tl->starts[tn-tl->min],readuntil-1, space>>20);
	tn-=tl->min;
	if ((fd=open(nam,O_TRUNC|O_CREAT|O_WRONLY|O_APPEND))==-1){
		fprintf(stderr,"%s: error opening wave file %s: %s\n",progname,nam,strerror(errno));
		exit(1);
	};
	if(fchmod(fd,opt_chmod)==-1){
		fprintf(stderr,"%s: error changing mode of wave file %s: %s\n",progname,nam,strerror(errno));
		exit(1);
	}
	if(opt_spchk && !check_for_space(nam, space)) {
		close(fd);
		unlink(nam);
		fprintf(stderr, "Not enough free space on disk for track %d\n",
				tn + tl->min);
		return 1;
	}
	header=cd_newave((readuntil-tl->starts[tn])*CD_FRAMESIZE_RAW);
	if(write(fd,&header,sizeof(header))==-1){
		fprintf(stderr,"%s: error writing wave file %s: %s\n",progname,nam,strerror(errno));
		exit(1);
	};
	/* main loop */
	bytes=0;p1=buf1;p2=buf2;q=0; int datatrack_has_spoken=0;
	cd_read_audio(tl->starts[tn],opt_blocks,(char *)p1);

	bcount = ldp = now = 0; sc = time((time_t*)0) - 1;
	for(i=tl->starts[tn]+opt_bufstep;i<readuntil;i+=opt_bufstep){
		/* jitter correction; a=number of bytes written */
		if(opt_verbose){
			now = time((time_t*) 0);
			if(ldp < now) {
				ldp = now;
				speed = bcount / (now - sc);
				printf("Reading block %7d - %2.2fx speed",i, (float) speed/75);
				if(speed > 0) {
					missing = (tl->starts[tn+1] - i) / speed;
					printf(" - %s left\r", resttime(missing));
				} else {
					printf("                \r");
				}
				fflush(stdout);
			}
			bcount += opt_bufstep;
		}
		q=0;
		do {

            if(stop_jittering_mode==1 && i + opt_blocks > readuntil){
               if(datatrack_has_spoken==0){
                  printf("Data track coming up - at %d we have read enough\n",d_tracks.byte_start-magic_pre_data_track_limit);
                  datatrack_has_spoken=1;
               }
               //cd_read_audio(i, d_tracks.byte_start,(char *)p2);
               break;
            }

			if((i+opt_blocks)<tl->starts[tn+1])
				cd_read_audio(i,opt_blocks,(char *)p2);
			else
				cd_read_audio(i,tl->starts[tn+1]-i,(char *)p2);
		}while (((n=cd_jc(p1,p2))==-1)&&(q++<opt_retrys)&&++retries);
		if(n==-1)
		{
			n=opt_bufstep*CD_FRAMESIZE_RAW;
			printf ("jitter error near block %d                                \n",i);
		};
		if(bytes+n>(tl->starts[tn+1]-tl->starts[tn])*CD_FRAMESIZE_RAW){
			n=(tl->starts[tn+1]-tl->starts[tn])*CD_FRAMESIZE_RAW-bytes;
		}
		if (n>0){
			if(opt_mono) {
				register int c, d;
				for(c = 0; c < (n>>2); c++) {
					d = p1[c];
					buf3[c] = ((short)(d&65535) + (short)(d>>16)) >> 1;
				}
				write(fd,buf3,n>>1);
			} else if(write(fd,p1,n)==-1){
				fprintf(stderr,"%s: error writing wave file %s: %s\n",
					progname,nam,strerror(errno));
				exit(1);
			};
			bytes+=n;
		}
		else{
			/*printf("errore!!\n");*/
			break;
		}
		p=p1;p1=p2;p2=p;
	}
	/* dump last bytes */
	int endpoint=tl->starts[tn+1];
	if(stop_jittering_mode==1){
        endpoint=d_tracks.byte_start - magic_pre_data_track_limit;
	}

	if (bytes<(endpoint-tl->starts[tn])*CD_FRAMESIZE_RAW){
		n=(endpoint-tl->starts[tn])*CD_FRAMESIZE_RAW-bytes;
		if(write(fd,p1,n)==-1){
			fprintf(stderr,"%s: error writing wave file %s: %s\n",progname,nam,strerror(errno));
			exit(1);
		};
		bytes+=n;
	}
	close (fd);
	if(opt_verbose) {
		printf("Track %d dumped at %2.2fx speed in %s            \n", 
				tn + tl->min, (float)speed/75, resttime(bcount/speed));
	}
	if(filter[0]) {
		snprintf(exec, BLEN, filter, nam);
		system(exec);
	}
	return 0;
}
void usage(void)
{
	fprintf(stderr,
			"\n%s v%s - dumps digital audio from cdrom to riff wave files\n"
			"Usage:\tdagrab [options] [track list]\nOptions:\n"
			"\t-h \t\t: show this message\n\t-i \t\t: display track list\n"
			"\t-d device\t: set cdrom device (default=%s)\n"
			"\t-a\t\t: dump all tracks (ignore track list)\n"
			"\t-v\t\t: verbose execution\n\t-f file\t\t: set output file name\n"
			"\t\t\t\tembed %%02d for track numbering\n"
			"\t-o overlap\t: sectors overlap for jitter correction, default %d\n"
			"\t-n sectors\t: sectors per request (default %d)\n"
			"\t\t\t warning: a number greater than that defined in your CD\n"
			"\t\t\t driver may cause unreported jitter correction failures \n"
			"\t-k key_length\t: size of key to match for jitter correction, default %d\n"
			"\t-r retries\t: read retries before reporting a jitter error (%d)\n"
			"\t-t offset\t: number of offsets to search for jitter correction (%d)\n"
			"\t-m mode  \t: default mode for files, will be chmod to mode (0%o)\n"
			"\t-e command\t: executes command for every copied track\n"
			"\t\t\t\tembed %%s for track's filename\n"
			"\t-s \t\t: enable free space checking before dumping a track\n"
			"\t-p \t\t: mono mode\n",
			PROGNAME,VERSION,CDDEVICE,OVERLAP,N_BUF,KEYLEN,
			RETRYS,OFS,D_MODE);
	exit(0);
}

#define CPARG(str) strncpy((str),optarg,BLEN); (str)[BLEN]=0

int main(int ac,char **av)
{
	int i,l,disp_TOC=0;
	char c;
	int all_tracks=0;
	struct cd_trk_list tl;
	char cd_dev[BLEN+1]=CDDEVICE;
	char basename[BLEN+1]="track%02d.wav";
	char filter[BLEN+1] = "";

	progname=av[0];
	optind=0;
	while((c=getopt(ac,av,"d:f:n:o:k:r:t:m:e:H:P:D:pshaivCSN"))!=EOF){
		switch(c){
			case 'h':usage();break;
			case 'd':CPARG(cd_dev);break;
			case 'f':CPARG(basename);break;
			case 'a':all_tracks=1;break;
			case 'i':disp_TOC=1;break;
			case 'n':opt_blocks=atoi(optarg);break;
			case 'o':opt_overlap=atoi(optarg);break;
			case 'k':opt_keylen=atoi(optarg);break;
			case 'v':opt_verbose=1;break;
			case 'r':opt_retrys=atoi(optarg);break;
			case 't':opt_ofs=atoi(optarg);break;
			case 'm':opt_chmod=strtol(optarg,(char**)0,8);break;
			case 'e':CPARG(filter);break;
			case 's':opt_spchk=1;break;
			case 'p':opt_mono=1;break;
		}
	}
	if(opt_blocks<4){
		opt_blocks=4;if(opt_verbose)
			fprintf(stderr,"sectors per request too low,setting to 4\n");
	};
	if(opt_blocks>200){
		opt_blocks=200;if(opt_verbose)
			fprintf(stderr,"sectors per request too high,setting to 200\n");
	};
	if(opt_overlap>opt_blocks-2){
		opt_overlap=opt_blocks-2;if(opt_verbose)
			fprintf(stderr,"overlap too high,setting to (sectors per request-2)\n");
	};
	if(opt_overlap<1){
		opt_overlap=1;if(opt_verbose)
			fprintf(stderr,"overlap too low,setting to 1\n");
	};
	if(opt_keylen<4){
		opt_keylen=4;if(opt_verbose)
			fprintf(stderr,"key too short,setting to 4\n");
	};
	if(opt_keylen>400){
		opt_keylen=400;if(opt_verbose)
			fprintf(stderr,"key too long,setting to 400\n");
	};
	if(opt_retrys>1000){
		opt_retrys=1000;if(opt_verbose)
			fprintf(stderr,"retrys too high,setting to 1000\n");
	};
	if(opt_retrys<1){
		opt_retrys=1;if(opt_verbose)
			fprintf(stderr,"retrys too low,setting to 1\n");
	};
	if(opt_ofs>256){
		opt_retrys=256;if(opt_verbose)
			fprintf(stderr,"offset too high,setting to 256\n");
	};
	if(opt_ofs<1){
		opt_ofs=1;if(opt_verbose)
			fprintf(stderr,"offset too low,setting to 1\n");
	};
	if(opt_chmod & ~07777) {
		opt_chmod=0660; if(opt_verbose)
			fprintf(stderr, "strange chmod value, setting to 0660\n");
	}
	opt_bufsize=CD_FRAMESIZE_RAW * opt_blocks;
	opt_ibufsize=opt_bufsize/sizeof(int);
	opt_bufstep=opt_blocks-opt_overlap;
	if((optind==ac)&&!all_tracks) {
		if(disp_TOC){
			if(cd_getinfo(cd_dev,&tl))
				exit(1);
			cd_disp_TOC(&tl, disp_TOC);
			exit(0);
		}
		else usage();
	};

	if(cd_getinfo(cd_dev,&tl)){
		exit(1);
	}

	cd_disp_TOC(&tl, disp_TOC);

	if(opt_verbose) fprintf(stderr,
			"sectors %3d overlap %3d key length %3d retrys %4d offset %3d\n",
			opt_blocks,opt_overlap,opt_keylen,opt_retrys,opt_ofs);
	if(all_tracks){
		printf("Dumping all tracks\n");
		for(i=tl.min;i<=tl.max;i++){
			cd_read_track(basename,i,&tl,filter);
		}
	}
	else
	{
		for(i=optind;i<ac;i++)
		{
			l=atoi(av[i]);
			if((l>=tl.min)&&(l<=tl.max)) {
				cd_read_track(basename,l,&tl,filter);
			}
		}
		
	}
	if(opt_verbose) {
		printf("Total retries for jitter correction: %d\n", retries);
	}

	exit(0);
}
