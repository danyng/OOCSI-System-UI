//--- LIBRARIES ---

import nl.tue.id.oocsi.*;
OOCSI oocsi;

import processing.video.*;
Movie myMovie;





//--- MODULE SPECIFICS ---

//define each module as an object
module T01;
module T02;
module T03;
module T04;
module T05;


//online state of each module acquired from oocsi.getClient.contains
boolean T01_online;
boolean T02_online;
boolean T03_online;
boolean T04_online;
boolean T05_online;


//unlock state of each module acquired through oocsi event
boolean T01_unlocked = false;
boolean T02_unlocked = false;
boolean T03_unlocked = false;
boolean T04_unlocked = false;
boolean T05_unlocked = false;





//---- SYSTEM SPECIFICS ---

//three different route sequences
String routeOrder [] []= { 
  {"T04", "T05", "T01", "T02", "T03"}, 
  {"T02", "T04", "T05", "T03", "T01"}, 
  {"T03", "T05", "T04", "T01", "T02"}
};

int currentRouteNumber = 0;

Boolean World_unlocked = false;


//list of modules ready to operate. order: start T01, end T05
Boolean Setup_finished [] = { false, false, false, false, false };
int setupCount = 0;




int currentTime = 0;





//--- VISUALS ---

//floorplan image initialization
PImage floorplanA;
PImage floorplanB;
PImage floorplanC;


//states whether the floormap is on fullscreen or not
boolean fullscreenSwitch = false;


//states whether the advertisement is on or not
boolean adSwitch = false;



/*predefine array for module positions
 - all positions are constraint and the same in all routes
 - all positions are finetuned only for the surface pro. No resizing possible yet
 - the positions are ordered starting from "T01" to last "T05"
 */

//module positions on the floormap 
int modulePositions [] [] = {
  {1130, 410}, 
  {1235, 675}, 
  {1235, 890}, 
  {572, 270}, 
  {1130, 310}
};

//module positions on the floormap when fullscreen
int modulePositionsFS [] [] = {
  {1510, 487}, 
  {1656, 842}, 
  {1656, 1122}, 
  {773, 299}, 
  {1510, 357}
};


//REMOVE THIS
//offset from the module
float nameTextOffset = 0.05;


//check hover over module to display instructions
boolean overT01 = false;
boolean overT02 = false;
boolean overT03 = false;
boolean overT04 = false;
boolean overT05 = false;









void setup() {

  fullScreen();
  background(50);


  //bootup message
  textSize(200);
  fill(255);
  text( "please wait 5 sec to boot up", 0, 0.9 * height );    //5 sec because it requires est. 1 sec per containsClient check


  //initialize the floorplan pictures
  floorplanA = loadImage("floorplanA.png");
  floorplanB = loadImage("floorplanB.png");
  floorplanC = loadImage("floorplanC.png");


  //initialize the advertisement video
  myMovie = new Movie(this, "advertisement.mp4");


  //define all modules as objects
  T01 = new module("T01");
  T02 = new module("T02");
  T03 = new module("T03");
  T04 = new module("T04");
  T05 = new module("T05");


  //connect to oocsi server
  //randomizing interface to make it accessible for multiple devices
  oocsi = new OOCSI(this, "Simple_UI_v4f_" + str(int(random(10000))), "oocsi.id.tue.nl");
  oocsi.subscribe("Tyria");
}
















/*the system is based on different checks to enter different stages in a hierarchical order.
 1. is the world unlocked?
 2. check the modules online state
 3. is the fullscreen switch on?
 4. draw the visuals
 */


void draw() {

  //check whether the world is unlocked
  if (World_unlocked) adSwitch = true;


  //when advertisement is on
  if (adSwitch) {

    background(0);

    displayAdVideo();
    displayAdDetails();


    //checks whether the modules are back online and ready
    //if 4 or more are ready, ad will be turned off and resume the interface
    if (checkSetup()) {
      adSwitch = false;
      println("setupCount is: " + setupCount);
    }
  } else {

    //ensure that he movie is not playing on the background
    myMovie.stop();


    background(80);


    floorplan();


    ////check whether this module is online or not
    ////requires a lot of processing power, so limit it through millis()
    ////checks every 10 sec (with delay of 5 sec for checking online status)
    checkOnlineStates();

    if (!fullscreenSwitch) {

      //show the floormap with the modules on it
      displayFloormapModules(fullscreenSwitch);


      //show info about clicked module
      displayInstructiontBox();

      //check whether the mouse is hovering on the module
      //update recalls another function to check the module location
      updateHover();
      displayInstructionText();


      //draw heartline on the right segment
      displayCenterLine(0.2, 0.1);
    } else {

      //show only the floormap with the modules on it
      displayFloormapModules(fullscreenSwitch);
    }
  }
}












//--- FLOORMAP WITH MODULES ---

void floorplan() {
  if (currentRouteNumber == 0) {
    displayFloorplan(0.08, fullscreenSwitch, floorplanA);
  } else if (currentRouteNumber == 1) {
    displayFloorplan(0.08, fullscreenSwitch, floorplanB);
  } else if (currentRouteNumber == 2) {
    displayFloorplan(0.08, fullscreenSwitch, floorplanC);
  }
}





//resize, position and display the floorplans
void displayFloorplan(float edgeOffset, boolean fullscreen, PImage floorplan) {

  if (fullscreen) {
    imageMode(CORNER);
    floorplan.resize(int(width * 0.8), 0);  //image is 80% of the display width when in fullscreen

    image(floorplan, 0, height * 0.07);
  } else {
    imageMode(CORNER);
    floorplan.resize(int(width * 0.6), 0);  //image is 60% of the display width

    image(floorplan, 0, edgeOffset * height);
  }
}









//define the modules on the floormap with class features
class module {


  //color specifics
  color rectC;
  color textC = color(255);

  //position specifics
  float yPosVert;

  //rectangle specifics
  float rectSize = 100;
  float cornerSize = 10;

  //module specifics
  String moduleName;
  int myRoutePosition;

  //module state specifics
  boolean onlineState = false;
  boolean unlockedState = false;





  //defining the module name to check states
  module(String myName) {
    moduleName = myName;
  }





  //capture the specifics, location and states of the module
  void define( boolean onlineState, boolean unlockedState, int currentRouteNumber ) {

    //defining the position within the route
    for ( int i = 0; i < routeOrder[0].length; i++ ) {

      //when my moduleName matches with the name on the route, capture the position through i
      if ( moduleName.equals( routeOrder[currentRouteNumber][i] ) == true ) {
        myRoutePosition = i;
      }
    }


    //defining the color of the module based on onlineState and unlockedState
    if (onlineState == true) {

      //when online, define the color of unlocked state
      if (unlockedState == true) {
        rectC = color(0, 255, 0);
      } else {
        rectC = color(255, 0, 0);
      }

      //when offline
    } else {
      rectC = color(100);
    }
  }





  //draw the rectangle on the floormap based on the predefined positions
  void display(int xPos, int YPos, float textYOffset, boolean fullscreen) {

    //offset for the text
    int offsetTextX;

    //define the shape specifics based on fullscreen state
    if (fullscreen) {
      rectSize = 120;
      cornerSize = 20;
      offsetTextX = 10;
    } else {
      rectSize = 100;
      cornerSize = 10;
      offsetTextX = 5;
    }



    //drawing the module as rectangle
    noStroke();
    rectMode(CORNER);

    fill(rectC);
    rect( xPos, YPos, rectSize, rectSize, cornerSize );


    //drawing the module names as text
    textAlign(CORNER);
    textSize(18);

    fill(textC);
    text( moduleName, xPos + offsetTextX, YPos + (height * textYOffset) );    //offset of 5 px to the right for left spacing


    //show routenumber on the right bottom corner
    textSize(200);

    fill(textC);
    text( currentRouteNumber + 1, 0.95 * width, 0.98 * height );



    //draw additional simple vertical overview of the modules when not in fullscreen
    if (!fullscreen) {

      //defining position in vertical axis as vertical ratio
      //+1 because myRoutePosition starts at 0
      yPosVert = float(myRoutePosition + 1) / 6;


      //drawing the module as rectangle
      noStroke();
      rectMode(CENTER);

      fill(rectC);
      rect( 0.8 * width, yPosVert * height, rectSize, rectSize, cornerSize );    //x is based on the heartline


      //place the text of the names on the box
      textAlign(CORNER);
      textSize(18);

      fill(textC);
      text( moduleName, 0.8 * width - 40, yPosVert * height + 30 );
    }
  }
}









//display the modules on the floormap
void displayFloormapModules(Boolean fullscreenSwitch) {

  if (!fullscreenSwitch) {

    //display all modules
    T01.define(T01_online, T01_unlocked, currentRouteNumber);
    T01.display(modulePositions[0][0], modulePositions[0][1], nameTextOffset, fullscreenSwitch);
    T02.define(T02_online, T02_unlocked, currentRouteNumber);
    T02.display(modulePositions[1][0], modulePositions[1][1], nameTextOffset, fullscreenSwitch);
    T03.define(T03_online, T03_unlocked, currentRouteNumber);
    T03.display(modulePositions[2][0], modulePositions[2][1], nameTextOffset, fullscreenSwitch);
    T04.define(T04_online, T04_unlocked, currentRouteNumber);
    T04.display(modulePositions[3][0], modulePositions[3][1], nameTextOffset, fullscreenSwitch);
    T05.define(T05_online, T05_unlocked, currentRouteNumber);
    T05.display(modulePositions[4][0], modulePositions[4][1], nameTextOffset, fullscreenSwitch);
  } else {

    //when fullscreen is true, only show floormap with modules
    T01.define(T01_online, T01_unlocked, currentRouteNumber);
    T01.display(modulePositionsFS[0][0], modulePositionsFS[0][1], nameTextOffset, fullscreenSwitch);
    T02.define(T02_online, T02_unlocked, currentRouteNumber);
    T02.display(modulePositionsFS[1][0], modulePositionsFS[1][1], nameTextOffset, fullscreenSwitch);
    T03.define(T03_online, T03_unlocked, currentRouteNumber);
    T03.display(modulePositionsFS[2][0], modulePositionsFS[2][1], nameTextOffset, fullscreenSwitch);
    T04.define(T04_online, T04_unlocked, currentRouteNumber);
    T04.display(modulePositionsFS[3][0], modulePositionsFS[3][1], nameTextOffset, fullscreenSwitch);
    T05.define(T05_online, T05_unlocked, currentRouteNumber);
    T05.display(modulePositionsFS[4][0], modulePositionsFS[4][1], nameTextOffset, fullscreenSwitch);
  }
}





















//--- INSTRUCTIONS ---



//display the instruction text box
void displayInstructiontBox() {

  //everything is predefined

  int offset = 12;  //shadow offset

  noStroke();
  rectMode(CORNER);  //aligns x and y to left corner

  fill(0);
  rect(-100 - offset, height * 0.75 + offset, 1000 + 245, 400, 30);


  fill(255, 215, 55);
  rect(-100, height * 0.75, 1000 + 245, 400, 30);
}









//CREATE FORLOOP

//checks whether the mouse is hovering on the module box
//only when the screen is not in fullscreen to represent the instructions of the module
void updateHover() {
  if ( hoverModule(int(modulePositions[0][0]), int(modulePositions[0][1]), 100, 100) ) {
    overT01 = true;
  } else {
    overT01 = false;
  }

  if ( hoverModule(int(modulePositions[1][0]), int(modulePositions[1][1]), 100, 100) ) {
    overT02 = true;
  } else {
    overT02 = false;
  }

  if ( hoverModule(int(modulePositions[2][0]), int(modulePositions[2][1]), 100, 100) ) {
    overT03 = true;
  } else {
    overT03 = false;
  }

  if ( hoverModule(int(modulePositions[3][0]), int(modulePositions[3][1]), 100, 100) ) {
    overT04 = true;
  } else {
    overT04 = false;
  }

  if ( hoverModule(int(modulePositions[4][0]), int(modulePositions[4][1]), 100, 100) ) {
    overT05 = true;
  } else {
    overT05 = false;
  }
}



//checks whether the mouse position is within the boundary of the module box
boolean hoverModule(int x, int y, int sizeX, int sizeY) {
  //current module rect are based on rectMode(CORNER)
  if (mouseX >= x && mouseX <= x + sizeX && 
    mouseY >= y && mouseY <= y + sizeY) {
    return true;
  } else {
    return false;
  }
}









//display the text on the instruction text box
void defineInstructionText(String text, int lineNumber, String fontStyling) {
  textAlign(LEFT, TOP);
  fill(255);

  int textSize;

  if (fontStyling == "heading") {
    textSize = 48;
  } else {
    textSize = 28;
  }


  int lineSpacing = int(textSize * 1.25);    //0.65 is proper
  textSize(textSize);
  text(text, 70, 0.8 * height + (lineNumber * lineSpacing) );
}




void displayInstructionText() {

  //when hover is on T01, display something
  if (overT01) {
    //box next to the textbox representing the module        
    displayModuleRepresentation("T01");

    //display text on the textbox
    defineInstructionText("Instructions T01 - Cup in the box(T05)", 0, "heading");
    defineInstructionText("Unlock by shaking the bottle 3 times.", 3, "paragraph");
    defineInstructionText("Don't be too fast, because then it will not be counted.", 4, "paragraph");
  } else if (overT02) {
    //box next to the textbox representing the module        
    displayModuleRepresentation("T02");

    //display text on the textbox
    defineInstructionText("Instructions T02 - Edge of the lunch table", 0, "heading");
    defineInstructionText("Stand between 10 - 60 cm in front of one table leg for 5 seconds", 3, "paragraph");
    defineInstructionText("then between 10-60 cm in front of the other table leg", 4, "paragraph");
    defineInstructionText("(on the short side of the table)", 5, "paragraph");
    defineInstructionText("holding a flat surface (i.e. tablet or book).", 6, "paragraph");
  } else if (overT03) {
    //box next to the textbox representing the module        
    displayModuleRepresentation("T03");

    //display text on the textbox
    defineInstructionText("Instructions T03 - Towel Hanger in kitchen", 0, "heading");
    defineInstructionText("Stand in front of the IR sensor for 8 seconds", 3, "paragraph");
    defineInstructionText("then move away from it for 10 seconds", 4, "paragraph");
    defineInstructionText("then stand in front of the sensor for 4 seconds", 5, "paragraph");
  } else if (overT04) {
    //box next to the textbox representing the module        
    displayModuleRepresentation("T04");

    //display text on the textbox
    defineInstructionText("Instructions T04 - LCD screen at the window", 0, "heading");
    defineInstructionText("Answer the question on the screen.", 3, "paragraph");
    defineInstructionText("1 dot? Press the left button three times.", 4, "paragraph");
    defineInstructionText("2 dots? Press the right button three times.", 5, "paragraph");
    defineInstructionText("3 dots? Press the buttons in the order left, right, left", 6, "paragraph");
  } else if (overT05) {
    //box next to the textbox representing the module        
    displayModuleRepresentation("T05");

    //display text on the textbox
    defineInstructionText("Instructions T05 - Black box on the shelf", 0, "heading");
    defineInstructionText("Close the lid of the box with force.", 3, "paragraph");
    defineInstructionText("If it doesn't work. Hit it on the side like a drum.", 4, "paragraph");
  } else {

    //when nothing has been selected
    //box next to the textbox representing the module        
    displayModuleRepresentation("T0_");

    defineInstructionText("General instructions - please read carefully", 0, "heading");
    defineInstructionText("Press on the module on the floormap for instructions.", 3, "paragraph");
    defineInstructionText("Press on anywhere on the screen to return to this message", 4, "paragraph");
    defineInstructionText("Every 10 sec, the interface refreshes and lags for couple seconds", 5, "paragraph");
    defineInstructionText("Colors: grey - offline, red - locked, green - unlocked", 6, "paragraph");

    defineInstructionText("Sorry for the inconvenience and enjoy :)", 7, "paragraph");
  }
}




//display the module display box next to the instruction box
void displayModuleRepresentation(String name) {

  int offset = 12;  //shadow offset in pixels

  //draw shadow
  fill(0);
  rectMode(CORNER);  //aligns x and y to left corner
  rect(150 - 50 + 800 + 100 - offset + 245, height * 0.75 + offset, 400, 400, 30);

  //draw box with color
  fill(0);
  strokeWeight(2);
  fill(255, 215, 55);
  rectMode(CORNER);  //aligns x and y to left corner
  rect(150 - 50 + 800 + 100 + 245, height * 0.75, 400, 400, 30);

  //draw text name
  fill(255);
  textSize(68);
  text( name, 1280 - 150 + 245, 1350 + 180 + 60);

  //draw line under name
  stroke(255);
  strokeWeight(6);
  line(1290 - 150 + 245, 1430 + 180, 1400 - 150 + 245, 1430 + 180);
}







//--- ADDITIONAL MODULE OVERVIEW ---


//draws a line for alignment for the additional module overview
void displayCenterLine(float offsetX, float offsetY) {      

  strokeWeight(2);
  stroke(255, 70);

  //offset values are ratios with the screen
  line( (1.0 - offsetX) * width, offsetY * height, (1.0 - offsetX)  * width, (1.0 - offsetY)  * height );
}










//--- ADVERTISEMENT ---

// Called every time a new frame is available to read
void movieEvent(Movie m) {
  m.read();
}





void displayAdVideo() {

  scale(1.425);
  myMovie.loop();  //this will make the video start
  image( myMovie, 0, height * 0.132 );

  scale(1/1.425);
}





//displaying details of the advertisement video
void displayAdDetails() {

  //draw grey bar
  noStroke();

  fill(0, 80);
  rect( 2736 - 190, 1150, 190, 70 );


  //draw yellow line as detail
  fill(255, 215, 55);
  rect( 2736 - 190 + 185, 1150, 5, 70);


  //text on bar: after the ad
  textSize(14);

  fill(255);
  text( "We will continue", 2736 - 160, 1165 );
  text( "after the ad", 2736 - 160, 1185 );


  //referencing the video
  textSize(10);

  fill(255);
  text( "This video belongs to the the Marvel Studio and we do not claim any right over them.", 50, height-50);
  text( "Allowance for displaying this video falls strictly under 'fair use' for educational purposes.", 50, height-35);
  text( "Reference: [Marvel Entertainment]. (2019, April 04). Marvel Studios' Avengers: Infinity War Official Trailer [Video File]. Retrieved from https://www.youtube.com/watch?v=6ZfuNTqbHE8", 50, height-20);


  //system unlocked announcement
  textSize(24);

  fill(255);
  text("Congratulations the system is unlocked. The stones are in the kitchen cupboard. Please wait for the next route.", 100, 50);
}


















//--- SYSTEM CHECK ---



////check whether this module is online or not
////requires a lot of processing power, so limit it through millis()
////checks every 10 sec (with delay of 5 sec for checking online status)
void checkOnlineStates() {

  millis();


  if (millis() + 300 > currentTime ) {
    textSize(60);
    textAlign(CORNER);

    fill(255);
    text( "refreshing", 0.85 * width, 0.05 * height );    //offset of 5 px to the right for left spacing
  }


  if (millis() > currentTime) {
    println("refresh online status. praise the 5 sec lag");

    T01_online = oocsi.getClients().contains("T01");
    T02_online = oocsi.getClients().contains("T02");
    T03_online = oocsi.getClients().contains("T03");
    T04_online = oocsi.getClients().contains("T04");
    T05_online = oocsi.getClients().contains("T05");

    println("refresh completed");

    currentTime = millis() + 10000;
  }
}





void Tyria(OOCSIEvent event) {

  //only capture this module's info when this module is not unlocked
  //if it is true, it will stay true and not ask for new status
  if ( !T01_unlocked ) 
    T01_unlocked = event.getBoolean("T01_unlocked", false);

  if ( !T02_unlocked ) 
    T02_unlocked = event.getBoolean("T02_unlocked", false);

  if ( !T03_unlocked ) 
    T03_unlocked = event.getBoolean("T03_unlocked", false);

  if ( !T04_unlocked ) 
    T04_unlocked = event.getBoolean("T04_unlocked", false);

  if ( !T05_unlocked ) 
    T05_unlocked = event.getBoolean("T05_unlocked", false);


  currentRouteNumber = event.getInt("route", 0);
  World_unlocked = event.getBoolean("World_unlocked", false);


  //checks whether the module has gone through the setup phase
  if ( event.getSender().equals("T01") )  Setup_finished[0] = event.getBoolean("Setup_finished", false); 
  if ( event.getSender().equals("T02") )  Setup_finished[1] = event.getBoolean("Setup_finished", false); 
  if ( event.getSender().equals("T03") )  Setup_finished[2] = event.getBoolean("Setup_finished", false); 
  if ( event.getSender().equals("T04") )  Setup_finished[3] = event.getBoolean("Setup_finished", false); 
  if ( event.getSender().equals("T05") )  Setup_finished[4] = event.getBoolean("Setup_finished", false); 


  println(World_unlocked);
}  




//a check if 4 or more modules are operational. The interface will skip the ad and continue
boolean checkSetup() {

  //reset the counter before checking
  setupCount = 0;

  //counts the amount of modules ready
  for (int i = 0; i < 4; i++) {
    if (Setup_finished[i] == true) {
      setupCount++;
    }
  }

  //checking with the requirements
  if (setupCount > 3) {
    return true;
  } else {
    return false;
  }
}












//--- TESTING CONTROLS ---

//key controls for triggering different states and routes
//not operational for the phantom thief
void keyReleased() {

  if (key == 'f') {
    fullscreenSwitch = !fullscreenSwitch;
  } else if (key == 'a') {
    adSwitch = !adSwitch;
  } else if (key == '1') {
    currentRouteNumber = 0;
  } else if (key == '2') {
    currentRouteNumber = 1;
  } else if (key == '3') {
    currentRouteNumber = 2;
  }
}
