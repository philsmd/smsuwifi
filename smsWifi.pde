/* SMSUWIFI
 * Copyright (C) 2011 by Philipp Schmidt
 *  
 * This file is part of the SMSUWIFI project
 *  
 * This Library is free software: you can redistribute it and/or modify 
 * it under the terms of the GNU General Public License as published by 
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This Library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *  
 * You should have received a copy of the GNU General Public License
 * along with this source files. If not, see
 * <http://www.gnu.org/licenses/>.
 */
#include <avr/pgmspace.h>
#include "libs/sdcard/FatReader.h"
#include "libs/sdcard/SdReader.h"
#include "libs/audio/WaveUtil.h"
#include "libs/audio/WaveHC.h"
#include <LiquidCrystal.h>

/*
 * Configuration
 */
// SMS settings
const char SMS_FORWARD_TEL[]="+123456789";        // my private mobile phone number
const char SMS_SIGNATURE[]="~RT:MY NAME.Bye";       // replace my name w/ your name
char sms_body[160];
const bool delete_older_sms=true;

// WiFly settings
bool wifly_is_cmd_mode=false;
char*wifly_protocol="HTTP/1.1";
const long wifly_check_connection=1800000;          // 30 Min (60*30*1000)
const unsigned int wifly_request_timeout=180000;    // 3 minutes until next SMS check
unsigned long wifly_last_connection_check,wifly_loop_timeout_begin,wifly_loop_timeout_stat;
const char*wifly_ssid="myRouterSSID";
const char*wifly_passphrase="topSecret";
const char*wifly_auth="3";
const char*wifly_hide="1";
const char*wifly_join="1";
const char*wifly_time_enable="5";
const char*wifly_time_zone="23";
const char*wifly_time_address="193.204.114.232";    // INRIM
const char*wifly_ip_dhcp="0";
const char*wifly_ip_address="192.168.0.2";
const char*wifly_ip_port="80";
const char*wifly_ip_port_ftp="5555";
const char*wifly_ip_gateway="192.168.0.1";
const char*wifly_ip_netmask="255.255.255.0";
const char*wifly_ip_protocol="2";
const char*wifly_comm_msg="0";
const char*wifly_comm_time="2000";
const char*wifly_comm_size="64";
const char*wifly_comm_match="0x0d";

// Audio settings
SdReader audio_card;
FatVolume audio_vol;    // Partition on the card
FatReader audio_root;
dir_t audio_dirBuf;
WaveHC audio_wave;
const char*AUDIO_SMS_ALERT="ALERT";
void audio_alert();     // function declaration

// LCD settings
LiquidCrystal lcd(32,30,28,26,24,22);   // interface pins
unsigned int lcd_sms_scroll_count=0,lcd_sms_pos=0;
const unsigned int lcd_max_tel_size=20,lcd_max_msg_size=320;
char lcd_tel[lcd_max_tel_size],lcd_msg[lcd_max_msg_size];
bool lcd_on=false;
unsigned long lcd_start;
const unsigned int LCD_MAX_DISPLAY=110000;
void lcd_update();                              // function declaration

// Serial port settings
// SMS module
HardwareSerial sms_serial=Serial;
int sms_modulePowerOn=2;        // the pin to switch on the module (w/o press on button) 
// LED settings
int led=13;
// WiFly module
HardwareSerial wifly_serial=Serial2;
// Debug
HardwareSerial debug_serial=Serial1;

// read_line settings
const int LINEBUF_SIZE=400;
char databuffer[LINEBUF_SIZE];
byte readLine_last_timeout=0;

// stuct for SMS messages
typedef struct smsNode {
    char id[7];
    char number[28];
    char date[11];
    char time[14];
    char content[400];
    struct smsNode *next;
} smsMessage;

// SMS message instance
smsMessage*sms_messageList;

// constants for time diff
const unsigned int SEC_PER_YEAR=31536000;       // 60*60*24*365
const unsigned int SEC_PER_MONTH=2592000;       // 60*60*24*30  
const unsigned int SEC_PER_DAY=86400;           // 60*60*24
const unsigned int SEC_PER_HOUR=3600;           // 60*60
const unsigned int SEC_PER_MINUTE=60;           // 60


/*
 * Start of functions
 */

// functions used for debugging
void start_debug() {
    debug_serial.begin(9600);            // DEBUG on 18 and 19
    debug_serial.flush();
    delay(100);
}

void debug(const char*str) {
    debug_serial.println(str);
    delay(100);
}

void debug_char(const char c) {
    debug_serial.println(c);
    delay(100);
}

void debug_cnt(const char*str) {
    debug_serial.write(str);
    delay(100);
}

void debug_int(const int num) {
    char str_num[255];
    itoa(num,str_num,10);
    debug_serial.write(str_num);
    delay(100);
}

void debug_long(const long num) {
    char str_num[255];
    ltoa(num,str_num,10);
    debug_serial.write(str_num);
    delay(100);
}

void debug_hex(int hex) {
    debug_serial.println(hex,HEX);
    delay(100);
}

// Led functions
void led_blink() {
    digitalWrite(led,HIGH);
    delay(100);
    digitalWrite(led,LOW);
}

// read serial output of modules
unsigned int read_line(HardwareSerial target,unsigned long timeout_ms=2000,bool checkLCD=false) {
    char *tptr=databuffer;
    unsigned long last_byte_time;
    readLine_last_timeout=0;   
    databuffer[0]=0x00;             // for sure null terminated
    last_byte_time=millis();
    while (true) {                  // end of loop w/ timeout or EOL
        // buffer is full
        if ((tptr-databuffer)>(LINEBUF_SIZE-2)) { // -2 so that last position can be set to null terminator.
            tptr[1]=0x00;
            break;
        } 
        if (target.available()>0) {   // is there sth available
            tptr[0]=target.read();      // read a byte
            tptr[1]=0x00;
            tptr++;
            last_byte_time=millis();
            if (((tptr[-1]=='\n')||(tptr[-1]=='\r'))&&(((int)(tptr-databuffer))==1)) { // newline (but ignoring empty lines)
                tptr=databuffer;
                databuffer[0]=0x00;
                continue;
            }
            if (tptr[-1]=='\r') {       // CR not at start of line (=> complete response)
                break;
            }
            continue; // don't check timeout since we got sth.
        } else if (checkLCD&&lcd_on) {
            lcd_update();
            delay(700);
        }
        // timeout check
        if (millis()-last_byte_time>timeout_ms) {
            tptr[1]='\0';
            readLine_last_timeout=1;      // timed out
            break;
        }
    } 
    return (int)(tptr-databuffer);  // amount of bytes read
}

// String helper functions
// trim functions
char*ltrim(char*s) {
    while(isspace(*s)||*s=='"')s++;
    return s;
}

char*rtrim(char*s) {
    char* back = s+strlen(s);
    while(isspace(*--back)||*back=='"');
    *(back+1)='\0';
    return s;
}

char*trim(char*s) {
    return rtrim(ltrim(s)); 
}

char*str_replace(char**orig,char*rep,char*with) {
    if (!*orig||!rep||!strlen(rep)||!strstr(*orig,rep)) {
        return *orig;
    }
    if (!with) {
        with=" "; 
    }
    int i,i_new,j,k;
    int orig_len=strlen(*orig);
    int repl_len=strlen(rep);
    int with_len=strlen(with);
    int diff_len=repl_len-with_len;
    for (i=0;i<orig_len;i++) {
        for (j=0;j<repl_len&&(i+j)<orig_len;j++) {
            if ((*orig)[i+j]!=rep[j]) {
                break;
            }
            if (j==repl_len-1) {
                // start actual replacement
                i_new=i;
                if (diff_len>0) {   // shrink length
                    for (k=0;k<orig_len-i;k++) {
                       (*orig)[i+k]=(*orig)[i+k+diff_len];
                    }
                    (*orig)[orig_len-diff_len]='\0';
                    orig_len-=diff_len;
                    i_new=i-diff_len-1;
                } else if (diff_len<0) {    // enlarge
                    for (k=orig_len-diff_len-1;k>i-diff_len;k--) {
                       (*orig)[k]=(*orig)[k+diff_len];
                    }
                    (*orig)[orig_len-diff_len]='\0';
                    orig_len-=diff_len;
                    i_new=i+diff_len-i;
                }
                // replace
                for (k=0;k<with_len;k++) {
                    (*orig)[i+k]=with[k];
                }
                i=i_new;
            }
        }
    }
    return *orig;
}

char*str_remove_from(char**orig,char*search) {
    if (strstr(*orig,search)) {
        char str_pointer;
        int length=strlen(*orig);
        int j,i,search_length=strlen(search);
        bool break_all=false;
        for (j=length-search_length;j>=0&&!break_all;j++){
            for (i=0;i<search_length;i++) {
                if ((*orig)[j+i]!=search[i]) {
                    break; 
                }
                if (i==(search_length-1)) {
                    (*orig)[j-1]='\0';
                    break_all=true;
                }
            }
        }
    }
    return *orig;
}

char*get_next_field(char**ptr,char*delimiter,char*dest,int max_length) {
    int pos=strcspn(*ptr,delimiter);
    int len=min(max_length-2,pos);
    strncpy(dest,*ptr,len);
    dest[len]='\0';
    len=strlen(dest);
    char last_char=dest[len-2];
    dest=trim(dest);
    int diff_length=len-strlen(dest);
    if (diff_length==2) {
        dest[len-2]='\0';
    }
    *ptr+=pos+1;     // modify pointer
    return dest;
}

// SMS module specific functions
void sms_get_imei(char*target) {
    sms_serial.println("AT+CGSN");
    read_line(sms_serial,200);     // imei itself
    int len = min(16,strcspn(databuffer,"\r\n"));
    memcpy(target,databuffer,len);
    target[len]='\0';
    read_line(sms_serial,300);     // OK
}

void sms_filter_incomming_calls() {
    delay(800);
    sms_serial.print("AT+KFILTER=");
    sms_serial.print(34,BYTE);          // the " char
    sms_serial.print(SMS_FORWARD_TEL);
    sms_serial.println(34,BYTE);
    read_line(sms_serial,300);
}

void sms_set_SMS_mode(bool text) {
    if (text) {
        sms_serial.println("AT+CMGF=1");    // mode: text
    } else {
        sms_serial.println("AT+CMGF=0");    // mode: PDU
    }
    read_line(sms_serial,300);                     // OK
}

void sms_send_SMS(const char*num,const char*body) {
    sms_serial.print("AT+CMGS=");
    sms_serial.print(34,BYTE);          // "
    sms_serial.print(num);              // SMS number
    sms_serial.println(34,BYTE);
    delay(1000);
    sms_serial.print(body);             // SMS body
    delay(500);
    sms_serial.print(0x1A,BYTE);        // end of message
    read_line(sms_serial,300);          // OK
    audio_alert();
}

void sms_delete_SMS(char*id) {
    sms_serial.print("AT+CMGD=");
    sms_serial.print(id);
    sms_serial.println(",0");
    delay(2000);
    read_line(sms_serial,500);
}

void sms_delete_all_SMS() {
    sms_serial.println("AT+CMGD=1,4");
    delay(2000);
    read_line(sms_serial,500);
}

void sms_set_sim_storage() {
    sms_serial.flush();
    sms_serial.print("AT+CPMS=");
    sms_serial.print(34,BYTE);
    sms_serial.print("SM");
    sms_serial.print(34,BYTE);
    sms_serial.print(",");
    sms_serial.print(34,BYTE);
    sms_serial.print("SM");
    sms_serial.println(34,BYTE);
    read_line(sms_serial,500);
}

smsMessage*sms_add_message(smsMessage*list,char*index,char*number,char*date,char*time,char*content) {
    smsMessage*lp=list;
    if (list!=NULL) {
        while (list->next!=NULL) {
            list=list->next;
        }
        list->next=(smsMessage*)malloc(sizeof(smsMessage));
        list=list->next;
        list->next=NULL;
        strcpy(list->id,index);
        strcpy(list->number,number);
        strcpy(list->date,date);
        strcpy(list->time,time);
        strcpy(list->content,content);
        return lp;
    } else {
        list=(smsMessage*)malloc(sizeof(smsMessage));
        list->next=NULL;
        strcpy(list->id,index);
        strcpy(list->number,number);
        strcpy(list->date,date);
        strcpy(list->time,time);
        strcpy(list->content,content);
        return list;
    } 
}

smsMessage*sms_list_SMS(int max_sms,char*type) {
    sms_serial.flush();
    int len,start_delimiter=0,total_len=0;
    int counter=1,max_field_length=30,max_index_length=5,blank_lines=0;
    char single_line[max_field_length],msg_index[7],msg_number[28],msg_date[11],msg_time[14],msg_content[400];
    char index[max_index_length+2];
    smsMessage*smsMessageList=NULL;
    char*str_ptr;
    sms_serial.print("AT+CMGL=");
    sms_serial.print(34,BYTE);
    sms_serial.print(type);
    sms_serial.println(34,BYTE);
    while (true) {
        read_line(sms_serial,1500);
        if (!(strncmp("OK",databuffer,2)==0)&&counter<=max_sms) {
            if (strlen(databuffer)>1) {
                if (strstr(databuffer,"+CMGL:")) {
                    str_ptr=databuffer;
                    get_next_field(&str_ptr,":",single_line,max_field_length);
                    strcpy(msg_index,get_next_field(&str_ptr,",",single_line,max_field_length));    // index
                    get_next_field(&str_ptr,",",single_line,max_field_length);                      // stat
                    strcpy(msg_number,get_next_field(&str_ptr,",",single_line,max_field_length));   // num
                    get_next_field(&str_ptr,",",single_line,max_field_length);                      // alpha
                    strcpy(msg_date,get_next_field(&str_ptr,",",single_line,max_field_length));     // date
                    strcpy(msg_time,get_next_field(&str_ptr,",",single_line,max_field_length));     // time
                    // read content
                    read_line(sms_serial,100);
                    smsMessageList=sms_add_message(smsMessageList,msg_index,msg_number,msg_date,msg_time,databuffer);
                    blank_lines=0;
                }
            } else {
                // exits the second time a blank line was found 
                if (blank_lines>0) {
                    break;
                } else {
                    blank_lines++;
                }
            }
        } else {
            break; 
        }
        counter++;
    }
    read_line(sms_serial,300);     // OK
    return smsMessageList;
}

void sms_setup_SMS() {
    sms_serial.begin(9600);             // baudrate for sms module
    pinMode(sms_modulePowerOn,OUTPUT);
    digitalWrite(sms_modulePowerOn,HIGH);
    delay(2000);
    digitalWrite(sms_modulePowerOn,LOW);
    for (int i=0;i<20;i++) {            // we need also the power to get signal
        delay(1000);
    }
    sms_set_SMS_mode(true);
    sms_filter_incomming_calls();
    sms_delete_all_SMS();
}

void sms_stop_module() {
    sms_serial.println("AT*PSCPOF");
    read_line(sms_serial,300);         // OK
}

// WiFly module specific functions
bool wifly_check_output(char*str) {
    unsigned int emptyLines=0;
    bool ret=false;
    do {
        ret=strstr(databuffer,str)!=NULL;
        read_line(wifly_serial,1500); 
        if (strlen(databuffer)<1) {
            emptyLines++; 
        } else {
            emptyLines=0;       // reset it
        }
    } while(!ret&&emptyLines<2);
    return ret;
}

void wifly_send_cmd_part(const char*cmd) {
    wifly_serial.print(cmd);
}

void wifly_send_cmd_part_int(const int num) {
    char str[25];
    itoa(num,str,10);
    wifly_send_cmd_part(str);
}

void wifly_send_cmd(const char*cmd,bool clearOutput=true) {
    wifly_serial.println(cmd);
    read_line(wifly_serial,200);
    if (clearOutput) {
        read_line(wifly_serial,200);
        read_line(wifly_serial,200);
    }
    delay(300);
}

bool wifly_enter_cmd_mode() {
    wifly_serial.write("$$$");
    read_line(wifly_serial,2500);
    bool ret = wifly_check_output("CMD");
    read_line(wifly_serial,200);
    read_line(wifly_serial,200);
    if (ret) {
        wifly_is_cmd_mode=true;
    }
    return ret;
}

void wifly_exit_cmd_mode() {
    wifly_send_cmd("exit");
    delay(800);
    wifly_is_cmd_mode=false;
}

bool wifly_is_connected() {
    bool ret=false;
    bool cmd_mode_before=wifly_is_cmd_mode;
    if (wifly_is_cmd_mode||wifly_enter_cmd_mode()) {
        wifly_send_cmd("get ip",false);
        delay(400);
        ret=wifly_check_output("F=UP");
        if (!cmd_mode_before) {
            wifly_exit_cmd_mode();
        }
        delay(1500);
        wifly_last_connection_check=millis();
    }
    return ret;
}

void wifly_close_connection() {
    if (wifly_enter_cmd_mode()) {
        wifly_send_cmd("close");
        wifly_exit_cmd_mode();
    }
}

void wifly_setup_wifi() {
    wifly_serial.begin(9600);
    while (!wifly_is_cmd_mode&&!wifly_enter_cmd_mode()) {
        delay(1500);
    }
    wifly_send_cmd_part("set wlan hide ");
    wifly_send_cmd(wifly_hide);
    wifly_send_cmd_part("set wlan phrase ");
    wifly_send_cmd(wifly_passphrase);
    wifly_send_cmd_part("set wlan ssid ");
    wifly_send_cmd(wifly_ssid);
    wifly_send_cmd_part("set wlan auth ");
    wifly_send_cmd(wifly_auth);
    wifly_send_cmd_part("set wlan join ");
    wifly_send_cmd(wifly_join);
    wifly_send_cmd_part("set time enable ");
    wifly_send_cmd(wifly_time_enable);
    wifly_send_cmd_part("set time zone ");
    wifly_send_cmd(wifly_time_zone);
    wifly_send_cmd_part("set time address ");
    wifly_send_cmd(wifly_time_address);
    wifly_send_cmd_part("set ip dhcp ");
    wifly_send_cmd(wifly_ip_dhcp);
    wifly_send_cmd_part("set ip address ");
    wifly_send_cmd(wifly_ip_address);
    wifly_send_cmd_part("set ip port");
    wifly_send_cmd(wifly_ip_port_ftp);
    wifly_send_cmd_part("set ip local ");
    wifly_send_cmd(wifly_ip_port);
    wifly_send_cmd_part("set ip gateway ");
    wifly_send_cmd(wifly_ip_gateway);
    wifly_send_cmd_part("set ip netmask ");
    wifly_send_cmd(wifly_ip_netmask);
    wifly_send_cmd_part("set ip protocol ");
    wifly_send_cmd(wifly_ip_protocol);
    wifly_send_cmd_part("set comm remote ");
    wifly_send_cmd(wifly_comm_msg);
    wifly_send_cmd_part("set comm time ");
    wifly_send_cmd(wifly_comm_time);
    wifly_send_cmd_part("set comm size ");
    wifly_send_cmd(wifly_comm_size);
    wifly_send_cmd_part("set comm match ");
    wifly_send_cmd(wifly_comm_match);
    wifly_send_cmd("time");
    wifly_send_cmd("save");
    delay(1400);
    if (!wifly_is_connected()) {
        wifly_send_cmd("reboot");
    }
    wifly_exit_cmd_mode();
}

int wifly_wait_for_request(char*search,const unsigned int timeout) {
    int ret=0;
    read_line(wifly_serial,timeout,true);
    if (strlen(databuffer)>0) {
        if (strstr(databuffer,search)&&strstr(databuffer,wifly_protocol)) {
            ret=2;
        } else {
            ret=1;
        }
    }
    return ret;
}

void wifly_answer_request(int res) {
    bool param_failure=true;
    int max_field_length=LINEBUF_SIZE-2,tel_length_max=26;
    char tel_nr[tel_length_max];
    char msg_content[max_field_length];
    if (res>1) { 
        int counter=0;
        bool is_tel=false,is_msg=false;
        char parse_line[max_field_length];
        char databuffer_cpy[LINEBUF_SIZE];
        char*databuffer_pointer;
        do {
            strcpy(databuffer_cpy,databuffer);
            databuffer_pointer=databuffer_cpy;
            if (strstr(databuffer_cpy,"?tel=")!=NULL) {
                get_next_field(&databuffer_pointer,"=",parse_line,max_field_length);
                strcpy(tel_nr,get_next_field(&databuffer_pointer,"&",parse_line,tel_length_max));
                databuffer_pointer-=2;
                is_tel=true;
            }
            if (strstr(databuffer_cpy,"&msg=")!=NULL) {
                get_next_field(&databuffer_pointer,"&",parse_line,max_field_length);
                get_next_field(&databuffer_pointer,"=",parse_line,max_field_length);
                strcpy(msg_content,get_next_field(&databuffer_pointer,"\n\r",parse_line,max_field_length));
                databuffer_pointer=msg_content;
                if (strlen(msg_content)>0) {
                    strcpy(msg_content,str_remove_from(&databuffer_pointer,wifly_protocol));
                }
                is_msg=true;
            }
            read_line(wifly_serial,1500);
            counter++;
        } while (counter<10&&(!is_tel||!is_msg));
        if (is_tel&&is_msg&&strlen(tel_nr)>2&&strlen(msg_content)>3) {
            char*msg_pointer=msg_content;
            strcpy(msg_content,str_replace(&msg_pointer,"%20"," "));
            param_failure=false;
        }
    }
    char html_body[350];
    if (res==1||param_failure) {
        strcpy(html_body,"<HTML><HEAD><TITLE>400 Bad Request</TITLE></HEAD><BODY><H1>Bad Request</H1>Your browser sent a request that this server could not understand.<P>Client sent malformed Host header<P><HR><ADDRESS>Apache Server at ");
        strcat(html_body,wifly_ip_address);
        strcat(html_body," Port ");
        strcat(html_body,wifly_ip_port);
        strcat(html_body,"</ADDRESS></BODY></HTML>");
        wifly_send_cmd_part("HTTP/1.1 400 Bad Request\r\nContent-Type: text/html;charset=UTF-8\r\nContent-Length: ");
        wifly_send_cmd_part_int(strlen(html_body));
        wifly_send_cmd_part("\r\nConnection: close\r\n\r\n");
        wifly_send_cmd(html_body);
        wifly_send_cmd_part("\t");
    } else {
        strcpy(html_body,"<html><body>\nOK<br>\nTEL: ");
        strcat(html_body,tel_nr);
        strcat(html_body,"<br>\nMSG: ");
        strcat(html_body,msg_content);
        strcat(html_body,"</body></html>");
        wifly_send_cmd_part("HTTP/1.1 200 OK\r\nContent-Type: text/html;charset=UTF-8\r\nContent-Length: ");
        wifly_send_cmd_part_int(strlen(html_body));
        wifly_send_cmd_part("\r\nConnection: close\r\n\r\n");
        wifly_send_cmd(html_body);
        wifly_send_cmd_part("\t");
        strcat(msg_content,SMS_SIGNATURE);
        sms_send_SMS(tel_nr,msg_content);
    }
    wifly_serial.flush();
    wifly_close_connection();
}

int get_next_field_int(char**ptr,char*delimiter) {
    int ret;
    char new_field[4];
    strcpy(new_field,get_next_field(ptr,delimiter,new_field,sizeof(new_field)/sizeof(char)));
    return atoi(new_field);
}

int get_date_diff(smsMessage*old_msg,smsMessage*new_msg) {
    int ret=0;
    char * str_ptr=new_msg->date;
    int newDay=get_next_field_int(&str_ptr,"/");
    int newMonth=get_next_field_int(&str_ptr,"/");
    int newYear=get_next_field_int(&str_ptr,"/");
    str_ptr=new_msg->time;
    int newHour=get_next_field_int(&str_ptr,":");
    int newMinute=get_next_field_int(&str_ptr,":");
    int newSecond=get_next_field_int(&str_ptr,"+-");
    int newOffset=get_next_field_int(&str_ptr,":");
    str_ptr=old_msg->date;
    int oldDay=get_next_field_int(&str_ptr,"/");
    int oldMonth=get_next_field_int(&str_ptr,"/");
    int oldYear=get_next_field_int(&str_ptr,"/");
    str_ptr=old_msg->time;
    int oldHour=get_next_field_int(&str_ptr,":");
    int oldMinute=get_next_field_int(&str_ptr,":");
    int oldSecond=get_next_field_int(&str_ptr,"+-");
    int oldOffset=get_next_field_int(&str_ptr,":");

    int diff_sec,diff_min,diff_hour,diff_offset,diff_day,diff_month,diff_year;
    diff_sec=newSecond-oldSecond;
    diff_min=newMinute-oldMinute;
    diff_hour=newHour-oldHour;
    diff_offset=newOffset-oldOffset;
    diff_day=newDay-oldDay;
    diff_month=newMonth-oldMonth;
    diff_year=newYear-oldYear;
    if (diff_year>0) {
        ret+=diff_year*SEC_PER_YEAR;
    } else if (diff_year<0) {
        ret+=(100+diff_year)*SEC_PER_YEAR;  // fake overflow
    }
    if (diff_month>0) {
        ret+=diff_month*SEC_PER_MONTH;
    } else if (diff_month<0) {
        ret+=(12+diff_month)*SEC_PER_MONTH; 
    }
    if (diff_day>0) {
        ret+=diff_day*SEC_PER_DAY;
    } else if (diff_day<0) {
        ret+=(30+diff_day)*SEC_PER_DAY;
    }
    if (diff_hour>0) {
        ret+=diff_hour*SEC_PER_HOUR;
    } else if (diff_hour<0) {
        ret+=(24+diff_hour)*SEC_PER_HOUR;
    }
    if (diff_offset!=0) {        // should always be in hours
        ret+=diff_offset*SEC_PER_HOUR;
    }
    if (diff_min>0) {
        ret+=diff_min*SEC_PER_MINUTE;
    } else if (diff_hour<0) {
        ret+=(60+diff_min)*SEC_PER_MINUTE;
    }
    if (diff_sec>0) {
        ret+=diff_sec;
    } else if (diff_sec<0) {
        ret+=(60+diff_sec);
    }
    return ret;
}

bool sender_received_sms_within(smsMessage*newMsg,int period,bool delete_older) {
    bool ret=false;
    int date_diff;
    smsMessage*oldMsg=sms_list_SMS(20,"REC READ");
    while (oldMsg!=NULL) {
        date_diff=get_date_diff(oldMsg,newMsg);
        if (date_diff<period) {
            if (strcmp(newMsg->number,oldMsg->number)==0&&strcmp(oldMsg->id,newMsg->id)!=0) {     // numbers must be identical
                ret=true;
                if (delete_older) {   // do NOT delete this message
                    sms_delete_SMS(oldMsg->id);                     // always delete older message
                    // no break after we found one, check also the rest
                } else {
                    break;
                }
            }
        } else if (date_diff>period&&delete_older&&strcmp(oldMsg->id,newMsg->id)!=0) {
            sms_delete_SMS(oldMsg->id);                             // always delete older message
        }
        oldMsg=oldMsg->next; 
    }
    return ret;
}

// Audio module specific functions
void audio_sdErrorCheck() {
    if (!audio_card.errorCode()) {
        return;
    }
    debug("SD I/O error: ");
    debug_hex(audio_card.errorCode());
    debug(", ");
    debug_hex(audio_card.errorData());
    while(1);
}

bool audio_isSdError() {
    return audio_card.errorCode();
}

bool audio_filecmp(dir_t &dir,const char*file_name) { 
    bool ret=true;
    uint8_t i;
    for (i=0;i<min(11,strlen(file_name));i++) {     // 8.3 format has 8+3 = 11 letters in it 
        if (dir.name[i]=='\0'||dir.name[i]==' '||dir.name[i]=='\n') {
            break;
        } else if (dir.name[i]!=file_name[i]) {
            ret=false;
            break;
        }
    }
    if (i<strlen(file_name)) {
        ret=false; 
    }
    return ret;
}


void audio_setup_wave() {
    for (int i=0;i<5;i++) {
        pinMode(10,OUTPUT);
        pinMode(11,OUTPUT);
        pinMode(12,OUTPUT);
        pinMode(13,OUTPUT);
        if (!audio_card.init()) {
            delay(800);
            if (i==4) {
                debug("Failed permanently");
                while(1);
            }
        } else {
            break; 
        }
    }
    audio_card.partialBlockRead(true);    // enable optimize read
    // look for a FAT partition
    uint8_t part;
    for (part=0;part<5;part++) {
        if (audio_vol.init(audio_card,part)) {
            break;
        }
    }
    if (part==5) {
        debug("No valid FAT partition!");
        audio_sdErrorCheck();
    }
    if (!audio_root.openRoot(audio_vol)) {
        debug("Can't open root dir!");
        while(1);
    }
}

void audio_play_file(FatReader folder,const char*file_name) {
    bool found=false;
    FatReader file;
    folder.rewind();
    while (folder.readDir(audio_dirBuf)>0) {  // Read every file
        if (audio_dirBuf.name[0]=='.') {
            continue;
        } else if (file.open(audio_vol,audio_dirBuf)&&!file.isDir()&&audio_filecmp(audio_dirBuf,file_name)) {
            found=true;
            break;
        }
    }
    if (found&&audio_wave.create(file)) {
        for (int i=0;i<7;i++) {
            audio_wave.play();
            while (audio_wave.isplaying) {
                delay(100);
            }
            if (!audio_isSdError()) {
                break;
            }
        }
    }
}

void audio_alert() {
    audio_play_file(audio_root,AUDIO_SMS_ALERT);
}

// LCD specific functions
void lcd_set_tel(const unsigned int pos) {
    lcd.setCursor(pos,0);
    lcd.print(lcd_tel);
}

void lcd_set_msg_part(unsigned int pos) {
    unsigned int len=strlen(lcd_msg);
    char*pointer;
    if (pos<len-15) {
        pointer=lcd_msg+pos;
    } else {
        pointer=lcd_msg;
        lcd_sms_pos=0;
    }
    char temp[18];
    strncpy(temp,pointer,min(strlen(pointer),16));
    temp[16]='\0';
    lcd.setCursor(lcd_sms_scroll_count,1);
    lcd.print(temp);
}

void lcd_show_sms(char*t,char*m) {
    lcd_start=millis();
    lcd.clear();
    lcd.display();
    lcd_on=true;
    // 1st row: tel
    unsigned int min_t=min(strlen(t),lcd_max_tel_size-2);
    strncpy(lcd_tel,t,min_t);
    lcd_tel[min_t]='\0';
    lcd_set_tel(0);

    // 2nd row: msg
    unsigned int min_m=min(strlen(m),lcd_max_msg_size-2);
    strncpy(lcd_msg,m,min_m);
    lcd_msg[min_m]='\0';
    lcd_set_msg_part(0);
}

void lcd_setup_display() {
    lcd.begin(16,2);
    lcd.noDisplay();
}

void lcd_update() {
    if (lcd_on) {
        lcd.scrollDisplayLeft();
        lcd_sms_scroll_count++;
        lcd_sms_pos++;
        lcd_set_msg_part(lcd_sms_pos);
        if (lcd_sms_scroll_count>15) {
            lcd.clear();
            lcd_sms_scroll_count=0;
        }
        lcd_set_tel(lcd_sms_scroll_count);
    }
}

// main
void setup() {
    start_debug();
    sms_setup_SMS();             // switch SMS module ON
    pinMode(led,OUTPUT);
    wifly_setup_wifi();
    audio_setup_wave();
    audio_alert();
    lcd_setup_display();
}

void loop() {
    // check incomming SMS
    led_blink();
    digitalWrite(led,HIGH);
    sms_messageList=sms_list_SMS(20,"REC UNREAD");
    if (sms_messageList!=NULL) {    // there are some (unread) SMS in the inbox
        audio_alert();
        if (strlen(sms_body)<2) {
            strcpy(sms_body,"Hi!I'm NO human,but I'm a f*cking cheap SMS module.I cannot answer your SMS and I'm suck to fwd. msgs to UR NAME.Contact him directly.Bye,idling again.Do NOT spam");
        }
        lcd_show_sms(sms_messageList->number,sms_messageList->content);
        while (sms_messageList!=NULL) {
            if (!sender_received_sms_within(sms_messageList,3600,delete_older_sms)) {
                sms_send_SMS(sms_messageList->number,sms_body);
            } 
            sms_messageList=sms_messageList->next; 
        }
    }
    // check LCD
    if (lcd_on&&millis()-lcd_start>LCD_MAX_DISPLAY) {
        lcd.noDisplay(); 
        lcd_on=false;
    }
    digitalWrite(led,LOW);
    // check WLAN connection
    if (millis()-wifly_last_connection_check>wifly_check_connection) {
        wifly_close_connection();
        while (!wifly_is_connected()) {
            wifly_setup_wifi();
            delay(500);
        }
    }
    // WiFly
    wifly_serial.flush();
    led_blink();
    led_blink();
    digitalWrite(led,HIGH);
    wifly_loop_timeout_begin=wifly_loop_timeout_stat=millis(); 
    while ((wifly_loop_timeout_stat+100-wifly_loop_timeout_begin)<wifly_request_timeout) {     // +100 to be sure that we will exit/finish if we are exactly in time
        int request_result=wifly_wait_for_request("*OPEN*",wifly_request_timeout-(wifly_loop_timeout_stat-wifly_loop_timeout_begin));
        if (request_result>0) {
            wifly_answer_request(request_result);
        }
        wifly_loop_timeout_stat=millis();
    }

    // wait a little bit before next iteration
    for (int i=0;i<3;i++) {
        delay(100);
        lcd_update();
    }
    digitalWrite(led,LOW);
}
