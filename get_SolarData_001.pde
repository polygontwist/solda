/*
Arduino 0022 get_SolarData_001

Strom&Spannung vom Solarpannel(s) 
speichern auf SD
speichern/abruf von Net

29.12.2011
*/

#include <SdFat.h>
#include <SdFatUtil.h>

#include <SPI.h>
#include <Ethernet.h>

#include <Flash.h>

#include <Wire.h>
#include <I2C_DS1307.h>  //Timer an I2C
//#include <I2C_PCF8574.h> //LCD an I2C //Flash:1454byte Ram:11byte
#include <I2C_LM75.h>    //Temperatursensoren

//#include <EEPROM.h> //Flash 38 RAM: 1

//-----------------------------Ethernet---------------------------
byte mac[] = { 0xAA, 0xDD, 0xEE, 0xAA, 0x55, 0x01 };
byte ip[] = { 192, 168,0, 10 };
Server server(80);

//-----------------------------SD-Card----------------------------
Sd2Card card;
SdVolume volume;
SdFile root;
SdFile file;
SdFile myFile;
//-----------------------------FlashDaten-------------------------
#define strPROGRAMM 0
#define strNETStatus 1
#define strNETCType 2
#define strTYPDATA 3

char buffer[40];

char memSysinfo00[] PROGMEM = "SolDa V0.9";
char memSysinfo01[] PROGMEM = ",";

char netstring0[] PROGMEM = "HTTP/1.1 ";
char netstring1[] PROGMEM = "404 Not Found";
char netstring2[] PROGMEM = "200 OK";

char netstring100[] PROGMEM = "Content-Type: ";
char netstring101[] PROGMEM = "text/";
char netstring102[] PROGMEM = "plain";
char netstring103[] PROGMEM = "html";
char netstring104[] PROGMEM = "image/icon";


char memstr00[] PROGMEM = "[time]";
char memstr01[] PROGMEM = "[date]";
char memstr02[] PROGMEM = "[day]";
char memstr03[] PROGMEM = "[list]";   //dateiliste
char memstr04[] PROGMEM = "[vers]";   //Progversion
char memstr05[] PROGMEM = "[temp3]";  //tempsensor 3
char memstr06[] PROGMEM = "[temp7]";  //tempsensor 7
char memstr07[] PROGMEM = "[a0]";  //AnalogPort 0
char memstr08[] PROGMEM = "[a1]";  //AnalogPort 1
char memstr09[] PROGMEM = "[a2]";  //AnalogPort 2
char memstr10[] PROGMEM = "[a3]";  //AnalogPort 3 (Port 4+5 wird fÃ¼r I2C benÃ¶tigt)


//_pointers_ zu obrigen Strings
char* myStringPointer[] PROGMEM ={//Programmstrings
   memSysinfo00,memSysinfo01
};

char* myNetPointer1[] PROGMEM ={ //EthernetNet Header Status
   netstring0,netstring1,netstring2
};
char* myNetPointer2[] PROGMEM ={ //EthernetNet Header Contenttype
   netstring100,
   netstring101,netstring102,netstring103,netstring104
 };

char* myDataTypPointer[] PROGMEM ={
   memstr00,memstr01,memstr02,memstr03,memstr04,
   memstr05,memstr06,
   memstr07,memstr08,memstr09,memstr10
};

String getmyString(uint8_t quelle, uint8_t pos){
  switch(quelle){
   case strPROGRAMM:
     strcpy_P(buffer, (char*)pgm_read_word(&(myStringPointer[pos])));
     break;
   case strNETStatus:
     strcpy_P(buffer, (char*)pgm_read_word(&(myNetPointer1[pos])));
     break;
   case strNETCType:
     strcpy_P(buffer, (char*)pgm_read_word(&(myNetPointer2[pos])));
     break;
   case strTYPDATA:
     strcpy_P(buffer, (char*)pgm_read_word(&(myDataTypPointer[pos])));
     break;
  // default:
  }
  return buffer;
}


//----------------------------------------------------------------
// call back for file timestamps
void dateTime(uint16_t* date, uint16_t* time) {
  // return date using FAT_DATE macro to format fields
  *date = FAT_DATE(I2C_DS1307.getYear(true), I2C_DS1307.getMonth(), I2C_DS1307.getDate());
  // return time using FAT_TIME macro to format fields
  *time = FAT_TIME(I2C_DS1307.getHour(), I2C_DS1307.getMinute(), I2C_DS1307.getSecond());
}
//----------------------------------------------------------------

void setup() {
  pinMode(10, OUTPUT); // set the SS pin as an output (necessary!)
  digitalWrite(10, HIGH); // but turn off the W5100 chip!

  card.init(SPI_HALF_SPEED, 4);
  volume.init(&card);
  root.openRoot(&volume);
  
  Wire.begin();
 // I2C_PCF8574.LCD_init(0);//LCD an Adress 0
  I2C_DS1307.setOutPin(true,0,false);//LED an 5V ausschalten  

  SdFile::dateTimeCallback(dateTime);// set date time callback function

  Ethernet.begin(mac, ip);
  server.begin();
  /*
  I2C_PCF8574.LCDwritestring(0, getmyString(strPROGRAMM,0));
  I2C_PCF8574.LCDwritestring(1, String(ip[0],DEC)+'.'+String(ip[1],DEC)+'.'+String(ip[2],DEC)+'.'+String(ip[3],DEC));
 */
 // EEPROM.write(0, 0);//counter fÃ¼r Netzugriffe 0..255
}


#define BUFSIZ 40  //zu lesende Zeichenkette max Zeichen (fÃ¼r GET und [tag]-Auswertung)

uint8_t lastminute=0;
uint8_t lastminuteCounter=0;

void loop(){
  uint8_t ec;
  //---------------------------LCD-------------------------------------------
  /*I2C_PCF8574.LCDwritekstring(0, 2, I2C_DS1307.getStringTime(false));
    String sh=I2C_DS1307.getStringDate(true);
    byte bb=16-sh.length();
    I2C_PCF8574.LCDwritekstring(bb, 2,sh);
    
    I2C_PCF8574.LCDwritekstring(0, 3, "3:");
    I2C_PCF8574.LCDwritekstring(8, 3, "7:");
    I2C_PCF8574.LCDwritekstring(2, 3,I2C_LM75.getStringTemperatur(3)+" ");
    I2C_PCF8574.LCDwritekstring(10, 3,I2C_LM75.getStringTemperatur(7)+" ");
    */
   delay(50);
    
  //----------------------------save-----------------------------------------  
    ec=I2C_DS1307.getMinute();
    if(ec!=lastminute){
      lastminuteCounter++;
      lastminute=ec;
    }
    
    if(lastminuteCounter>=5){//alle 5 Minuten speichern
      lastminuteCounter=0;
      
      char savefilename[]="yymmtt.csv"; //yymmtt.csv
      //uint16_t index2 = 0;
      
      //uint8_t temp;
      //uint8_t temp2;
      
      ec=I2C_DS1307.getYear(false);
      savefilename[0]=(48+ec/10);
      savefilename[1]=(48+ec%10);

      ec=I2C_DS1307.getMonth();
      savefilename[2]=(48+ec/10);
      savefilename[3]=(48+ec%10);
      
      ec=I2C_DS1307.getDate();
      savefilename[4]=(48+ec/10);
      savefilename[5]=(48+ec%10);

      //save
      //I2C_PCF8574.LCDwritestring(0, savefilename);
      if (myFile.open(&root, savefilename, O_RDWR | O_CREAT | O_AT_END)) {//
        myFile.print(I2C_DS1307.getStringTime(false));
        myFile.print(getmyString(strPROGRAMM,1));
        myFile.print(I2C_LM75.getStringTemperatur(3));
        myFile.print(getmyString(strPROGRAMM,1));
        myFile.print(I2C_LM75.getStringTemperatur(7));
        
        myFile.print(getmyString(strPROGRAMM,1));
        myFile.print(analogRead(A0));
        myFile.print(getmyString(strPROGRAMM,1));
        myFile.print(analogRead(A1));
        myFile.print(getmyString(strPROGRAMM,1));
        myFile.print(analogRead(A2));
        myFile.print(getmyString(strPROGRAMM,1));
        myFile.println(analogRead(A3));        
       }
      myFile.close();
    }
    
    
   
  //----------------------------NET------------------------------------------  
  Client client = server.available();
  if (client) {
    while (client.connected()) {
      if (client.available()) { 
        char clientline[BUFSIZ];
        uint16_t index = 0;       
        uint8_t c;
       
        
        //GET Angefragte Datei ermitteln
        c = client.read();        
        while (c!=13){
           clientline[index] = c;//Array of Chars
           index++;
           c = client.read();
           if (index >= BUFSIZ)break;
        }        
        
        clientline[index] = 0;//null Termination
        char *filename;
        char *optionen;
        
        (strstr(clientline, " HTTP"))[0] = 0;// a little trick, look for the " HTTP/1.1" string and
                                             // turn the first character of the substring into a 0 to clear it out.
        
        //------------Ãœbergabeparameter----------------
        if (strstr(clientline, "?") != 0){ // [GET /dateinam.htm?value=12345]
         
          if (strstr(clientline, "&") != 0)
            (strstr(clientline, "&"))[0] = 0; //nur einen Ã¼bergabepameter!
          
          optionen=strstr(clientline, "?");//Pointer
          optionen=optionen+1;//Pointer  "var=12345"
          
          //Optionen zum z.B. Uhrenstellen
          //
          char *wert;
          wert=strstr(clientline, "=");
          wert=wert+1;
          
          (strstr(clientline, "="))[0] = 0;// "=" mit null ersten
          
          if (strstr(optionen, "h") != 0){
            c=chrlisttobyte(wert);
            if(c<24)I2C_DS1307.setHour(c);
          }
          if (strstr(optionen, "m") != 0){
            c=chrlisttobyte(wert);
            if(c<60)I2C_DS1307.setMinute(c);
          }
         if (strstr(optionen, "Y") != 0){
            c=chrlisttobyte(wert);
            if(c<100)I2C_DS1307.setYear(c);
          }
         if (strstr(optionen, "M") != 0){
            c=chrlisttobyte(wert);
            if(c>0 && c<13)I2C_DS1307.setMonth(c);
          }
          if (strstr(optionen, "T") != 0){
            c=chrlisttobyte(wert);
            if(c>0 && c<32)I2C_DS1307.setDate(c);
          }
          
          //"?..." Ãœbergabeparameter weg fÃ¼r Dateiname
          (strstr(clientline, "?"))[0] = 0; 
        }
         
        filename = clientline + 5; // look after the "GET /" (5 chars)
         
        if(filename[0]==0)filename="index.htm"; //keine Datei Ã¼bergeben: index.htm laden
         
        //-----------Datei Ã¶ffnen, wenn es fehlschlÃ¤gt 505 ausgebem------------------
        if (! file.open(&root, filename, O_READ)) {
            client.print  (getmyString(strNETStatus,0));     //"HTTP/1.1 "
            client.println(getmyString(strNETStatus,1));     //"404 Not Found"
            client.print  (getmyString(strNETCType,0));     //"Content-Type: "
            client.print(getmyString(strNETCType,1));       //"text/"
            client.println(getmyString(strNETCType,2));     //"plain"
            client.println();
            client.println(getmyString(strNETStatus,1));      //"404 Not Found"
            client<<F(">");
            client.print(filename);                //Dateiname
            client<<F("<");
            break;//while (client.connected()) verlassen, Net-Komunikation beenden
          }
        //Datei ist vorhanden, ausgeben:
        
        //----------header----------
        client.print  (getmyString(strNETStatus,0));       //"HTTP/1.1 "
        client.println(getmyString(strNETStatus,2));       //"200 OK"
        client.print  (getmyString(strNETCType,0));       //"Content-Type: "
       
        bool inhaltparsen=false;
        if ((strstr(filename, ".htm") != 0) || (strstr(filename, ".HTM") != 0)){ 
          client.print(getmyString(strNETCType,1));     //"text/"  
          client.println(getmyString(strNETCType,3));     //"html" 
           inhaltparsen=true;
         } 
        else
        if((strstr(filename, ".ico") != 0) || (strstr(filename, ".ICO") != 0)){
          client.println(getmyString(strNETCType,4));     //"image/icon"
         }
        else
         {//funktioniert auch mit Bildern
          client.print(getmyString(strNETCType,1));     //"text/"
          client.println(getmyString(strNETCType,2));   //"plain"
         }
        client.println();

        
        //----------inhalt-----------
        index=0;        
        clientline[0] = 0;    
        bool tagopen=false;
        
        int16_t c2 = file.read();
        while (c2 > -1){
          if(inhaltparsen){
                   if(c2==91)tagopen=true;  //"["
                   if(!tagopen) client.print((char)c2);
                   
                   if(tagopen){
                      clientline[index] = c2;     //gelesenes Byte in Puffer schreiben
                      index++;                    //Puffercounter hochzÃ¤hlen  
                      if(index>=BUFSIZ){          //PufferÃ¼berlauf
                        index--;
                        clientline[index] = 0;    //letzten Wert lÃ¶schen und 0 reinschreiben (0-terminierter String)
                        client.print((String)clientline);//Puffer ausgeben
                        client.print((char)c2);   //letztes Zeichen ausgeben
                        index=0;
                        tagopen=false;           //tag konnte nicht gelesen werden(zu lang)->ist irgendwas anderes
                        }
                      }                
                   
                   if(c2==93 && tagopen){//"[Tag]"                 --------Datenausgabe--------     
                         clientline[index] = 0;

                         if(String(clientline) == getmyString(strTYPDATA,0)){//[time] Serverzeit hh:mm
                            client.print(I2C_DS1307.getStringTime(false));
                         }else
                        if(String(clientline) == getmyString(strTYPDATA,1)){//[date] ServerDatum tt.mm.yyyy
                             client.print(I2C_DS1307.getStringDate(true));
                        }else
                        if(String(clientline) == getmyString(strTYPDATA,2)){//[day] ServerTag als Zahl 1=Montag
                             c2=I2C_DS1307.getDay();
                             client.print(String(c2,DEC));
                        }else
                       if(String(clientline) == getmyString(strTYPDATA,3)){//[list]  Dateiliste
                            ListFiles(client);
                         }else
                       if(String(clientline) == getmyString(strTYPDATA,4)){//[vers] Progversion
                            client.print(getmyString(strPROGRAMM,0));
                         }else
                        
                        //Sensoren:
                        if(String(clientline) == getmyString(strTYPDATA,5)){//[temp3] tempsensor 3
                            client.print(I2C_LM75.getStringTemperatur(3));
                         }else
                        if(String(clientline) == getmyString(strTYPDATA,6)){//[temp7] tempsensor 7
                            client.print(I2C_LM75.getStringTemperatur(7));
                         }else
                         if(String(clientline) == getmyString(strTYPDATA,7)){ //[a0] Analog 0  0...1023
                            client.print(analogRead(A0));
                         }else
                        if(String(clientline) == getmyString(strTYPDATA,8)){  //[a1] Analog 1
                            client.print(analogRead(A1));
                         }else
                       if(String(clientline) == getmyString(strTYPDATA,9)){   //[a2] Analog 2
                            client.print(analogRead(A2));
                         }else
                        if(String(clientline) == getmyString(strTYPDATA,10)){ //[a3] Analog 3
                            client.print(analogRead(A3));
                         }else
                         
                         //nix weiter
                         client.print((String)clientline);//Tag gibt es nicht, inhalt so ausgeben
                          
                         index=0;
                         tagopen=false; //"]"                         
                       }
                  
                 }//html
              else
               client.print(char(c2));//text,bin                
                 
             c2 = file.read();//nÃ¤chstes Zeichen
        }
                
        file.close();                           //Datzei schlieÃŸen
        break;                                  //while verlassen        
      }//if (client.available())
    }// while (client.connected())
    delay(1);
    client.stop();
  }//if (client)   
}

uint8_t chrlisttobyte(char *cahrlist){//Ã¼bergabe=pointer Zahl sls "String" "0".."255" zu einem byte konvertieren
 uint8_t re=0;
 uint8_t cc;
 for(uint8_t t=0;t<BUFSIZ;t++){
   cc=cahrlist[t];
   if(cc==0)break;
   if(cc>47 && cc<58){//0123456789
     if(t>0)re=re*10;
     re=re+(cc-48);
   }
 }
 return re;
}

void ListFiles(Client client) {
  // This code is just copied from SdFile.cpp in the SDFat library
  // and tweaked to print to the client output in html!
  dir_t p; 
  root.rewind();
  client << F("<ul>");  
  while (root.readDir(p) > 0) {
    // done if past last used entry
    if (p.name[0] == DIR_NAME_FREE) break;
 
    // skip deleted entry and entries for . and  ..
    if (p.name[0] == DIR_NAME_DELETED || p.name[0] == '.') continue;
 
    // only list subdirectories and files
    if (!DIR_IS_FILE_OR_SUBDIR(&p)) continue;
 
    // print any indent spaces
    client << F("<li>");
    
    // DateiÃ¤nderungsdatum & -zeit 
   //if (flags & LS_DATE) {
       uint16_t data=p.lastWriteDate; //gepackte Datenstrucktur
       client << F(" ");     
       client.print(String(FAT_YEAR(data),DEC)); 
       client << F("-");
       if(FAT_MONTH(data)<10)client << F("0");
       client.print(String(FAT_MONTH(data),DEC)); 
       client << F("-");
       if(FAT_DAY(data)<10)client << F("0");
       client.print(String(FAT_DAY(data),DEC)); 
       client << F(" ");
       data=p.lastWriteTime;        //gepackte Datenstrucktur
       if(FAT_HOUR(data)<10)client << F("0");
       client.print(String(FAT_HOUR(data),DEC)); 
       client << F(":");
       if(FAT_MINUTE(data)<10)client << F("0");
       client.print(String(FAT_MINUTE(data),DEC)); 
       client << F(":");
       if(FAT_SECOND(data)<10)client << F("0");
       client.print(String(FAT_SECOND(data),DEC)); 
    // }
    //Datei verlinken 
    client << F(" <a href=\"");    
    for (uint8_t i = 0; i < 11; i++) {  //8.3
      if (p.name[i] == ' ') continue;   //leerzeichen Ã¼berlesen
      if (i == 8)   client << F(".");  //nach 8 zeichen kommt die Endung
      client.print(p.name[i]);
    }    
    client << F("\">");
 
    // print file name with possible blank fill
    for (uint8_t i = 0; i < 11; i++) {
      if (p.name[i] == ' ') continue;
      if (i == 8)   client << F(".");
      client.print(p.name[i]);
    }
 
    client << F("</a>"); 
    //if (DIR_IS_SUBDIR(&p)) client << F("/");  
 
    // print size if requested
    //if (!DIR_IS_SUBDIR(&p) ) {//&& (flags & LS_SIZE)
      client << F(" ");
      client.print(p.fileSize);
    //}
    client << F("</li>");
    client.println();
  }
  client << F("</ul>");
  
}
