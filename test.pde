import java.util.Collections;
import java.util.Comparator;
import java.util.Random;

Player player;
World world;
Random r;

void setup() {
    r = new Random();
    size(500, 1000);
    player = new Player(250, 50, radians(90));
    world = new World();
    world.fillRandom();
    line(200, 0, 200, 1000);
    line(300, 0, 300, 1000);
    for (Obstacle o : world.obstacles) {
        o.drawObstacle();
    }
}

void draw() {
    player.move();
    player.drawPlayer();
    //player.grab(world.getClosestObstacle(player.c));
    if (player.checkCrash() || player.c.y > 1000) {
        noLoop();
    }
}

void mousePressed(){
    player.grab(world.getClosestObstacle(player.c));
}

void mouseReleased(){
    player.unGrab();
}

class World {
    ArrayList<Obstacle> obstacles;

    public World() {
        obstacles = new ArrayList();
    }

    public void addObstacle(Obstacle o) {        //assumes that obstacles are added in sorted order
        obstacles.add(o);
    }
    
    public Obstacle getClosestObstacle(Coordinate coord){
         return getClosestObstacles(coord).get(0);
    }
    
    public ArrayList<Obstacle> getClosestObstacles(Coordinate coord){
        ArrayList<Obstacle> obsArray = new ArrayList(obstacles);
         final Coordinate c = coord;
         Collections.sort(obsArray, new Comparator<Obstacle>() {
             public int compare(Obstacle o1, Obstacle o2) {
                 return o1.distanceTo(c) < o2.distanceTo(c) ? -1 : o1.distanceTo(c) == o2.distanceTo(c) ? 0 : 1;
             }
         });
         return obsArray;
    }
    
    public void fillRandom(){
        for (int i = 100; i < 1000; i += 100){
            obstacles.add(new Obstacle(r.nextInt(100) + 200, r.nextInt(100) + i, r.nextInt(10) + 5));
        }
    }
}

class Player {
    public static final double PLAYER_SPEED = 3.0;
    public static final double PLAYER_DIAMETER = 6.0;
    public double angle;        //or keep track of vx and vy
    public Coordinate c;
    public Obstacle grabTarget;

    public Player() {
        this(new Coordinate(0, 0), 0);
    }

    public Player(double x, double y, double angle) {      //NOTE: angle is in radians, in 0-360 format
        this(new Coordinate(x, y), angle);
    }

    public Player(Coordinate c, double angle) {
        this.c = c;
        this.angle = angle;
        grabTarget = null;
    }

    public void grab(Obstacle target) {
        if (compareAngle(target)){
             grabTarget = target;
        }
    }

    public void unGrab() {
        grabTarget = null;
    }

    public void move() {
        if (grabTarget == null) {
            nonGrabMove();
        } else {
            grabMove();
        }
    }

    private boolean checkCrash() {
        if ((player.c.x < 200 || player.c.x > 300) && player.grabTarget == null){
            die();
             return true;   
        }
        for (Obstacle o : world.obstacles) {
            if (o.containsPoint(c, PLAYER_DIAMETER / 2)) {
                die();
                return true;
            }
        }
        return false;
    }
    
    public void die(){
        fill(255, 0, 0);
        ellipse((float)c.x, (float)c.y, 25, 25);
        fill(255, 255, 255);
    }

    private void grabMove() {
        double distance = sqrt(pow((float)grabTarget.c.y - (float)c.y, 2.0) + pow((float)grabTarget.c.x - (float)c.x, 2.0));
        double circumfrence = 2 * PI * distance;
        double relativeAngle = getRelativeAngle(grabTarget);
        double newRelativeAngle = relativeAngle;
        double angleChange = (TWO_PI * PLAYER_SPEED)/circumfrence;
        if (clockWise(grabTarget)){
        //if (true) {
            //clockwise
            newRelativeAngle += angleChange;
            angle = newRelativeAngle + HALF_PI;
            //System.out.print("Clockwise, ");
        } else {
            //counterclockwise
            newRelativeAngle -= angleChange;
            angle = newRelativeAngle - HALF_PI;
            //System.out.print("Counterclockwise, ");
        }
        while (newRelativeAngle < 0){
             newRelativeAngle += TWO_PI;   
        }
        while (newRelativeAngle >= TWO_PI){
             newRelativeAngle -= TWO_PI;   
        }
        while (angle < 0){
             angle += TWO_PI;   
        }
        while (angle >= TWO_PI){
             angle -= TWO_PI;   
        }
        double xOff = distance * cos((float)newRelativeAngle);
        double yOff = distance * sin((float)newRelativeAngle);
        Coordinate newC = new Coordinate(grabTarget.c.x + xOff, grabTarget.c.y + yOff);
        c = newC;
        //System.out.println("Distance: " + distance + ", Relative angle: " + degrees((float)relativeAngle) + ", Angle change: " + degrees((float)angleChange) + ", New Relative Angle: " + degrees((float)newRelativeAngle) + ", Angle: " + degrees((float)angle) + ", xOff: " + xOff + ", yOff: " + yOff);
    }
    
    public boolean clockWise(Obstacle o){
        double relativeAngle = getRelativeAngle(o);
        double clockwiseTangent = relativeAngle + HALF_PI;
        double counterclockwiseTangent = relativeAngle - HALF_PI;
        if (clockwiseTangent > TWO_PI){
             clockwiseTangent -= TWO_PI;   
        }
        if (counterclockwiseTangent < 0){
            counterclockwiseTangent += TWO_PI;
        }
        double clockTangentComp = abs((float)angle - (float)clockwiseTangent);
        double counterTangentComp = abs((float)angle - (float)counterclockwiseTangent);
        if (clockTangentComp > 180){
             clockTangentComp = 360 - clockTangentComp;   
        }
        if (counterTangentComp > 180){
             counterTangentComp = 360 - counterTangentComp;   
        }
        return clockTangentComp < counterTangentComp;        
    }

    public boolean compareAngle(Obstacle o) {                //returns if valid to grab
        double angle1 = degrees(atan2((float)(o.c.y - c.y), (float)(o.c.x - c.x)));
        double angle2 = angle1;
        if (angle2 < 0) {
            angle2 += 360;
        }
        return abs((float)angle2 - (float)getAngle360()) >= 90 || abs((float)angle1 - (float)getAngle180()) >= 90;
    }
    
    public double getRelativeAngle(Obstacle o){                        //returns in radians, 0-360 degree format
        double retVal = atan2((float)(c.y - o.c.y), (float)(c.x - o.c.x));
        //System.out.println("xOff: " + (c.x - o.c.x) + ", yOff: " + (c.y - o.c.y) + ", Relative angle: " + retVal);
        if (retVal < 0){
             retVal += TWO_PI;   
        }
        //System.out.println(c.x + " " + c.y);
        return retVal;
    }

    public double getAngle180() {
        double retVal = degrees((float)angle);
        while (retVal < -180) {
            retVal += 360;
        }
        while (retVal > 180) {
            retVal -= 360;
        }
        return retVal;
    }

    public double getAngle360() {
        return degrees((float)angle);
    }

    private void nonGrabMove() {
        c.x += PLAYER_SPEED * cos((float)angle);
        c.y += PLAYER_SPEED * sin((float)angle);
    }

    public void drawPlayer() {
        if (grabTarget != null){
             line((float)c.x, (float)c.y, (float)grabTarget.c.x, (float)grabTarget.c.y);
        }
        ellipse((float)c.x, (float)c.y, (float)PLAYER_DIAMETER, (float)PLAYER_DIAMETER);
    }
}

class Obstacle {
    public Coordinate c;
    public double diameter;
    
    public Obstacle() {
        this(new Coordinate(0, 0), 0);
    }

    public Obstacle(double x, double y, double r) {
        this(new Coordinate(x, y), r);
    }

    public Obstacle(Coordinate c, double r) {
        this.c = c;
        this.diameter = r;
    }

    public void drawObstacle() {
        ellipse((float)c.x, (float)c.y, (float)diameter, (float)diameter);
    }

    public boolean containsPoint(Coordinate p, double offset) {
        return sqrt(pow((float)p.x - (float)c.x, 2) + pow((float)p.y - (float)c.y, 2)) < diameter / 2 + offset;
    }
    
    public double distanceTo(Coordinate loc){
         return sqrt(pow((float)c.x - (float)loc.x, 2) + pow((float)c.y - (float)loc.y, 2));
    }
}

class Coordinate {
    double x, y;

    public Coordinate(double x, double y) {
        this.x = x;
        this.y = y;
    }
}
