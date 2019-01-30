import java.util.Collections;
import java.util.Comparator;
import java.util.Random;

Player player;
Random r;

final int WORLD_LENGTH = 1000;
final int WORLD_WIDTH = 500;
final int INITIAL_PLAYER_ANGLE = 90;
final int INITIAL_PLAYER_X = 250;
final int INITIAL_PLAYER_Y = 50;
final int LEFT_LINE_X = 200;
final int RIGHT_LINE_X = 300;
final int OBSTACLES_Y_START = 100;
final int OBSTACLES_Y_END = WORLD_LENGTH;
final int OBSTACLES_INTERVAL = 100;
final int OBSTACLES_MIN_SIZE = 5;
final int OBSTACLES_SIZE_RANGE = 10;
final double PLAYER_SPEED = 3.0;
final double PLAYER_DIAMETER = 6.0;
final float PLAYER_DEATH_DIAMETER = 20.0;

void setup() {
    r = new Random();
    size(WORLD_WIDTH, WORLD_LENGTH);
    player = new Player(INITIAL_PLAYER_X, INITIAL_PLAYER_Y, radians(INITIAL_PLAYER_ANGLE));
    World world = new World();
    world.fillRandom();
    world.drawn = true;
    player.world = world;
    line(LEFT_LINE_X, 0, LEFT_LINE_X, WORLD_LENGTH);
    line(RIGHT_LINE_X, 0, RIGHT_LINE_X, WORLD_LENGTH);
    for (Obstacle o : world.obstacles) {
        o.drawObstacle();
    }
}

void draw() {
    if (player == null){
        noLoop();
    }
    player.handleMove();
    if (!player.alive){
        noLoop();
    }
}

void mousePressed(){
    if (player != null){
        player.grab(player.world.getClosestObstacle(player.c));
    }
}

void mouseReleased(){
    if (player != null){
        player.unGrab();
    }
}

//runs a single player forward in time, returning their ultimate y coordinate as a score
RunResults runPlayer(Player player){
    int turnsTaken = 0;
    while(player.alive){
       player.handleMove();
       turnsTaken++;
    }
    return new RunResults(turnsTaken, player.c.y);
}

class RunResults {
    public int turns;
    public double score;
    
    public RunResults(int turns, double score){
        this.turns = turns;
        this.score = score;
    }
}

class World {
    public ArrayList<Obstacle> obstacles;
    public boolean drawn;

    public World() {
        obstacles = new ArrayList();
        drawn = false;
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
        for (int i = OBSTACLES_Y_START; i < OBSTACLES_Y_END; i += OBSTACLES_INTERVAL){
            obstacles.add(new Obstacle(r.nextInt(RIGHT_LINE_X - LEFT_LINE_X) + LEFT_LINE_X, r.nextInt(OBSTACLES_INTERVAL) + i, r.nextInt(OBSTACLES_SIZE_RANGE) + OBSTACLES_MIN_SIZE));
        }
    }
}

class Player {
    public double angle;        //or keep track of vx and vy
    public Coordinate c;
    public Obstacle grabTarget;
    public boolean grabbedLast;
    public World world;
    public boolean alive;

    public Player() {
        this(new Coordinate(0, 0), 0);
    }

    public Player(double x, double y, double angle) {      //NOTE: angle is in radians, in 0-360 format
        this(new Coordinate(x, y), angle);
    }

    //Handles one tick of movement for the player, including dying and grabbedLast;
    //Version in draw() is deprecated, due to unique requirements of draw();
    public void handleMove(){
        move();
        drawPlayer();
        if (checkCrash() || c.y > WORLD_LENGTH){
            die();
        }
        if (grabTarget == null){
            grabbedLast = false;
        } else {
            grabbedLast = true;
        }
    }

    public Player(Coordinate c, double angle) {
        this.c = c;
        this.angle = angle;
        grabTarget = null;
        grabbedLast = false;
        alive = true;
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
        if ((c.x < LEFT_LINE_X || c.x > RIGHT_LINE_X) && grabTarget == null && grabbedLast == false){
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
        if (world.drawn){
            fill(255, 0, 0);
            ellipse((float)c.x, (float)c.y, PLAYER_DEATH_DIAMETER, PLAYER_DEATH_DIAMETER);
            fill(255, 255, 255);
        }
        alive = false;
    }

    private void grabMove() {
        double distance = sqrt(pow((float)grabTarget.c.y - (float)c.y, 2.0) + pow((float)grabTarget.c.x - (float)c.x, 2.0));
        double circumfrence = 2 * PI * distance;
        double relativeAngle = getRelativeAngle(grabTarget);
        double newRelativeAngle = relativeAngle;
        double angleChange = (TWO_PI * PLAYER_SPEED)/circumfrence;
        if (clockWise(grabTarget)){
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
        c = new Coordinate(grabTarget.c.x + xOff, grabTarget.c.y + yOff);
        //System.out.println("Distance: " + distance + ", Relative angle: " + degrees((float)relativeAngle) + ", Angle change: " + degrees((float)angleChange) + ", New Relative Angle: " + degrees((float)newRelativeAngle) + ", Angle: " + degrees((float)angle) + ", xOff: " + xOff + ", yOff: " + yOff);
    }
    
    //determines if player should or should not rotate clockwise about the given target object
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
        if (world.drawn){
            if (grabTarget != null){
                 line((float)c.x, (float)c.y, (float)grabTarget.c.x, (float)grabTarget.c.y);
            }
            ellipse((float)c.x, (float)c.y, (float)PLAYER_DIAMETER, (float)PLAYER_DIAMETER);
        }
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
