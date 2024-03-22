import java.util.*;
import java.nio.*;
import java.io.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.Function;
import java.util.function.Consumer;
import java.nio.channels.FileChannel;

ApplicationClass s_ApplicationClass = new ApplicationClass();
DebugProfilerClass s_DebugProfiler = new DebugProfilerClass();
PGraphics s_3D;
int s_deltaTime;

void setup() {
  fullScreen(P2D, SPAN);

  s_DebugProfiler.startProfileTimer();

  surface.setTitle("High5ive Flight Sim - 2024 v3.5.2b LTS");
  surface.setResizable(!FULLSCREEN_ENABLED);
  surface.setLocation(0, 0);

  frameRate(FRAME_RATE);

  textFont(createFont("Century Gothic Bold", 48, true));

  s_3D = createGraphics(width, height, P3D);
  s_3D.hint(ENABLE_DEPTH_SORT);
  if (!s_3D.isGL()) {
    println("OpenGL is not available. Make sure hardware acceleration is enabled.");
  }

  s_ApplicationClass.init();

  s_DebugProfiler.printTimeTakenMillis("All Setup");
}

void draw() {
  s_ApplicationClass.frame();
}

void keyPressed() {
  s_ApplicationClass.onKeyPressed(key, keyCode);
}

void mousePressed() {
  s_ApplicationClass.onMouseClick();
}

void mouseMoved() {
  s_ApplicationClass.onMouseMoved();
}

void mouseDragged() {
  s_ApplicationClass.onMouseDragged();
}

void mouseWheel(MouseEvent event) {
  s_ApplicationClass.onMouseWheel(event.getCount());
}

// Descending code authorship changes:
// F. Wright, Made setup(), draw(), 8pm 23/02/24
// F. Wright, Made input functions for use in InputClass such as keyPressed(), 9pm 23/02/24
// F. Wright, Made mouse related functions for use in ApplicationClass and Widgets. Set up window resizing, 6pm 04/03/24
// F. Wright, Modified and simplified UI code to fit coding standard. Combined all UI elements into the UI tab, 6pm 04/03/24
// F. Wright, Used symbolic linking to allow us to put all UI pde files into subfolder, 11pm 05/03/24
// M. Poole, Modified to add to add mouseWheel(), 1pm 12/3/24
// CKM, implemented working fullscreen 15:00 12/03
// CKM, commented out deprecated input class 16:00 12/03
// CKM, moved all imported libraries into main 00:00 15/03
