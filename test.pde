import java.util.Collections;
import java.util.Comparator;
import java.util.Random;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Vector;

import org.neuroph.contrib.neat.gen.Organism;
import org.neuroph.contrib.neat.gen.operations.fitness.AbstractFitnessFunction;
import org.neuroph.core.NeuralNetwork;
import org.neuroph.contrib.neat.gen.impl.SimpleNeatParameters;

Player player;
Random r;
ArrayList<World> worlds;

static final int WORLD_LENGTH = 1000;
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
final int TEST_WORLDS_SIZE = 5;
final int NEURAL_NET_OBSTACLES_BEFORE = 1;        //number of obstacles with y <= player.c.y given to the nn
final int NEURAL_NET_OBSTACLES_AFTER = 4;        //number of obstacles with y >= player.c.y given to the nn
final int NEURAL_NET_OBSTACLES_TOTAL = NEURAL_NET_OBSTACLES_BEFORE + NEURAL_NET_OBSTACLES_AFTER;

void setup() {
    r = new Random();
    //size(WORLD_WIDTH, WORLD_LENGTH);
    size(500, 1000);                        //REMEMBER TO RESET THIS
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
    
    initWorlds();
    try {
       player.net = trainNet();
    } catch (Exception e) {
        System.err.println(e.getMessage());
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

void initWorlds(){
    worlds = new ArrayList();
    for (int i = 0; i < TEST_WORLDS_SIZE; i++){
        World w = new World();
        w.fillRandom();
        worlds.add(w);
    }
}

NeuralNetwork trainNet() throws PersistenceException{
    SimpleNeatParameters params = new SimpleNeatParameters();
    params.setFitnessFunction(new OMLFitnessFunction());
    params.setPopulationSize(5);
    params.setMaximumFitness(OMLFitnessFunction.MAXIMUM_FITNESS);
    params.setMaximumGenerations(10);
    
    NaturalSelectionOrganismSelector selector = new NaturalSelectionOrganismSelector();
    selector.setKillUnproductiveSpecies(true);
    selector.setElitismEnabled(true);
    selector.setSurvivalRatio(.5);
    params.setOrganismSelector(selector);
    
    ArrayList<NeuronGene> inputGenes = new ArrayList();
    for (int i = 0; i < NEURAL_NET_OBSTACLES_TOTAL * 3 + 3; i++) {
        inputGenes.add(new NeuronGene(NeuronType.INPUT, params));
    }
    ArrayList<NeuronGene> outputGenes = new ArrayList();
    outputGenes.add(new NeuronGene(NeuronType.OUTPUT, params));
    
    Evolver evolver = null;
    try {
        evolver = Evolver.createNew(params, inputGenes, outputGenes);
    } catch (Exception e){
        System.out.println(e.getMessage());
        e.printStackTrace();
    }
    Organism best = evolver.evolve();
    
    return params.getNeuralNetworkBuilder().createNeuralNetwork(best);
}

class OMLFitnessFunction extends AbstractFitnessFunction {
    static final int MAXIMUM_FITNESS = WORLD_LENGTH;
    
    double evaluate (Organism o, NeuralNetwork nn) {
        int netScore = 0;
        for (World world : worlds){
            Player player = new Player(INITIAL_PLAYER_X, INITIAL_PLAYER_Y, radians(INITIAL_PLAYER_ANGLE));
            player.world = world;
            netScore += runPlayer(player).score;        //TODO: more advanced calculation of fitness
        }
        return (double)netScore;
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
    
    //gets the relevant obstacles for a given coordinate
    //the obstacle before and the four after the given location
    //if any of these don't exist, the value at that index will be null
    public ArrayList<Obstacle> getNetObstacles(Coordinate c) {
        ArrayList<Obstacle> netObs = new ArrayList();
        //add in valid after objects and before object, valid or not
        for (int i = 0; i < obstacles.size(); i++) {
            if (netObs.size() == NEURAL_NET_OBSTACLES_TOTAL) {
                break;
            }
            if (obstacles.get(i).c.y > c.y && netObs.size() == 0) {
                if (i == 0){
                    netObs.add(null);
                } else {
                    netObs.add(obstacles.get(i-1));
                }
                i--;
                continue;            //to ensure functionality in the event of 0 forward obstacles given
            }
            if (obstacles.get(i).c.y > c.y){
                netObs.add(obstacles.get(i));
            }
            
        }
        //add in invalid after objects
        while (netObs.size() < NEURAL_NET_OBSTACLES_TOTAL){
            netObs.add(null);
        }
        return netObs;
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
    NeuralNetwork net;

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
        grabbedLast = false;
        alive = true;
    }
    
    public String toString(){
        return "Angle: " + radians((float)angle) + ", X: " + c.x + ", Y: " + c.y;
    }
    
    public void setNetworkInput(){
        if (world == null || net == null){
            return;
        }
        ArrayList<Obstacle> obstacles = world.getNetObstacles(c);
        double[] networkInput = new double[NEURAL_NET_OBSTACLES_TOTAL * 3 + 3];
        for (int i = 0; i < NEURAL_NET_OBSTACLES_TOTAL; i++){
            if (obstacles.get(i) != null) {
                networkInput[i * 3] = obstacles.get(i).c.x - c.x;
                networkInput[i * 3 + 1] = obstacles.get(i).c.y - c.y;
                networkInput[i * 3 + 2] = obstacles.get(i).diameter / 2.0;
            } else {
                networkInput[i * 3] = -1000000.0;
                networkInput[i * 3 + 1] = -100000.0;
                networkInput[i * 3 + 2] = -100000.0;
            }
        }
        networkInput[NEURAL_NET_OBSTACLES_TOTAL * 3] = c.x - LEFT_LINE_X;
        networkInput[NEURAL_NET_OBSTACLES_TOTAL * 3 + 1] = PLAYER_SPEED * sin((float)angle);
        networkInput[NEURAL_NET_OBSTACLES_TOTAL * 3 + 2] = PLAYER_SPEED * cos((float)angle);
        net.setInput(networkInput);
    }

    //Handles one tick of movement for the player, including dying and grabbedLast;
    public void handleMove(){
        if (net != null){
            setNetworkInput();
            if (net.getOutput().get(0) > 0){
                grab(world.getClosestObstacle(c));
            } else {
                unGrab();
            }
        }
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
