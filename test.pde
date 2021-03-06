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
//ArrayList<World> worlds;
ArrayList<World> trainWorlds;
ArrayList<World> testWorlds;
boolean isRunning;
int worldIndex;
int gfxOffset;

static final int WORLD_LENGTH = 10000;
final int WORLD_WIDTH = 800;
final int WORLD_SECTION_LENGTH = 1000;
final int INITIAL_PLAYER_ANGLE = 90;
final int LEFT_LINE_X = 100;
final int RIGHT_LINE_X = 200;
final int INITIAL_PLAYER_X = (LEFT_LINE_X + RIGHT_LINE_X) / 2;
final int INITIAL_PLAYER_Y = 50;
final int OBSTACLES_Y_START = 100;
final int OBSTACLES_Y_END = WORLD_LENGTH;
final int GAP_OBSTACLES = 2;
final int GAP_WIDTH = 20;
final int OBSTACLES_INTERVAL = 100;
final int OBSTACLES_MIN_SIZE = 5;
final int OBSTACLES_SIZE_RANGE = 10;
final double PLAYER_SPEED = 3.0;
final double PLAYER_DIAMETER = 6.0;
final float PLAYER_DEATH_DIAMETER = 20.0;
static final int TRAIN_WORLDS_SIZE = 20;        //It is recommended not to make this too small
static final int TEST_WORLDS_SIZE = 5 + TRAIN_WORLDS_SIZE;
final int NEURAL_NET_OBSTACLES_BEFORE = 1;        //number of obstacles with y <= player.c.y given to the nn
final int NEURAL_NET_OBSTACLES_AFTER = 4;        //number of obstacles with y >= player.c.y given to the nn
final int NEURAL_NET_OBSTACLES_TOTAL = NEURAL_NET_OBSTACLES_BEFORE + NEURAL_NET_OBSTACLES_AFTER;
final int NEURAL_NET_VALUES_PER_OBSTACLE = 3;
final int NEURAL_NET_OTHER_VALUES = 3;
final int NEURAL_NET_TOTAL_VALUES = (NEURAL_NET_OBSTACLES_BEFORE + NEURAL_NET_OBSTACLES_AFTER) * NEURAL_NET_VALUES_PER_OBSTACLE + NEURAL_NET_OTHER_VALUES;
final double NEURAL_NET_GRAB_THRESHOLD = .8;
final float SURVIVAL_RATIO = .5;
final double NEURONS_SIGMOID_SLOPE = .2;
final int MAXIMUM_SIMULATION_TURNS = (int)((WORLD_LENGTH / PLAYER_SPEED) * 4.0);
final int DEFAULT_BACKGROUND_COLOR = 200;
final int VIEW_DELAY_MS = 100;
final int TEXT_X_OFFSET = 10;
final int TEXT_Y_OFFSET = 10;
final int GRAPH_X_START = RIGHT_LINE_X + 100;
final int GRAPH_Y_START = 0;
final int GRAPH_HEIGHT = 500;
final int GRAPH_WIDTH = 500;
final float IDLE_SCORE_MULTIPLIER = .5;
final float NULL_OBSTACLE_VALUE = -1000000.0;
final int PLAYER_COLOR_BLANK = 255;
final int PLAYER_COLOR_ATTEMPTED_GRAB = 150;
final int PLAYER_COLOR_SUCCESSFUL_GRAB = 50;
final int[] DEAD_PLAYER_RGB = {255, 0, 0};
final int[] BASE_LINE_RGB = {255, 0, 0};
final int[] TREND_LINE_RGB = {0, 0, 255};
final int[] BORDER_RGB = {0, 0, 0};

final int POPULATION_SIZE = 100;
final int GENERATIONS_COUNT_MAX = 200;

final boolean MANUAL_CONTROL = false;
final boolean NOCLIP = false;
final boolean PRINT_NET_OUTPUT = false;

//tracking for generation-based statistics
double globalMaxFitness;
double[] localMaxFitness;
int playersSinceGeneration;
int generation;
//int baseScore;
long baseTime;
long simulationTime;
long runTime;
long moveTime0;
long moveTime1;
long moveTime2;
long networkTime;
long obstacleTime;

void setup() {
    baseTime = System.currentTimeMillis();
    simulationTime = 0;
    runTime = 0;
    moveTime0 = 0;
    moveTime1 = 0;
    moveTime2 = 0;
    obstacleTime = 0;
    networkTime = 0;
	isRunning = false;
	localMaxFitness = new double[GENERATIONS_COUNT_MAX * 10];		//TODO: fix
	worldIndex = 0;
	System.out.println("START");
	r = new Random();
	//size(WORLD_WIDTH, WORLD_SECTION_LENGTH);
	size(800, 1000);                        //REMEMBER TO RESET THIS
	player = new Player(0, 0, 0);            //these get overwritten anyways
	initWorlds();
	if (!MANUAL_CONTROL) {
		try {
			player.net = trainNet();
			System.out.println(netToString(player.net));
		} 
		catch (Exception e) {
    		System.out.println("ERROR START *****************");
			System.err.println(e.getMessage());
			System.err.println(Arrays.deepToString(e.getStackTrace()));
			System.out.println("ERROR END *******************");
		}
	}
	testWorlds.get(0).drawn = true;
	setupWorld(testWorlds.get(0));
	/*
	System.out.println("MAX SCORE: " + globalMaxFitness);
	System.out.println("LOCAL SCORES: ");
	for (int i = 0; i < localMaxFitness.length; i++) {
    	System.out.println("GEN: " + i + ", SCORE: " + localMaxFitness[i]);
	}
	*/
	//System.out.println("BASE SCORE: " + baseScore);
	System.out.println("Total Time: " + (System.currentTimeMillis() - baseTime));
	System.out.println("Simulation Time: " + simulationTime);
	System.out.println("Run time: " + runTime);
	System.out.println("Move time 0: " + moveTime0);
	System.out.println("Move time 1: " + moveTime1);
	System.out.println("Move time 2: " + moveTime2);
	System.out.println("Network time: " + networkTime);
	System.out.println("Obstacle time: " + obstacleTime);
	isRunning = true;
}

void draw() {
	if (player == null) {
		noLoop();
	}
	player.handleMove(0);
	if (!player.alive) {
		delay(VIEW_DELAY_MS);
		nextWorld();
	}
}

void nextWorld() {
    testWorlds.get(worldIndex).drawn = false;
    worldIndex +=1;
    worldIndex %= TEST_WORLDS_SIZE;
    testWorlds.get(worldIndex).drawn = true;
    setupWorld(testWorlds.get(worldIndex));
}

void setupWorld(World w) {
	player.resetPlayer(INITIAL_PLAYER_X, INITIAL_PLAYER_Y, radians(INITIAL_PLAYER_ANGLE));
	player.world = w;
	gfxOffset = 0;
	setupGfx(w, gfxOffset);
}

void setupGfx(World w, int offset) {
	background(DEFAULT_BACKGROUND_COLOR);
	line(LEFT_LINE_X, 0, LEFT_LINE_X, WORLD_SECTION_LENGTH);
	line(RIGHT_LINE_X, 0, RIGHT_LINE_X, WORLD_SECTION_LENGTH);
	text("World: " + worldIndex + "\nOffset: " + gfxOffset, TEXT_X_OFFSET, TEXT_Y_OFFSET);
	drawGraph();
	for (Obstacle o : w.obstacles) {
		o.drawObstacle(offset);
	}
}

void drawGraph() {
    rect(GRAPH_X_START, GRAPH_Y_START, GRAPH_WIDTH, GRAPH_HEIGHT);
    stroke(TREND_LINE_RGB[0], TREND_LINE_RGB[1], TREND_LINE_RGB[2]);
    float x = GRAPH_X_START;
    float dx = GRAPH_WIDTH/(GENERATIONS_COUNT_MAX - 1);
    //float scaleFactor = (float)(GRAPH_HEIGHT/(globalMaxFitness > baseScore ? globalMaxFitness : baseScore));
    float scaleFactor = (float)(GRAPH_HEIGHT/globalMaxFitness);
    for (int i = 1; i < localMaxFitness.length; i++) {
    	line(x + dx * (i - 1), GRAPH_HEIGHT - (float)localMaxFitness[i-1] * scaleFactor + GRAPH_Y_START, x + dx * i, GRAPH_HEIGHT - (float)localMaxFitness[i] * scaleFactor + GRAPH_Y_START);
    }
    //stroke(BASE_LINE_RGB[0], BASE_LINE_RGB[1], BASE_LINE_RGB[2]);
    //line(GRAPH_X_START, GRAPH_HEIGHT - baseScore * scaleFactor + GRAPH_Y_START, GRAPH_X_START + GRAPH_WIDTH, GRAPH_HEIGHT - baseScore * scaleFactor + GRAPH_Y_START);
    stroke(BORDER_RGB[0], BORDER_RGB[1], BORDER_RGB[2]);
}

void mousePressed() {
    nextWorld();
	if (player != null && MANUAL_CONTROL) {
		player.grab(player.world.getClosestObstacle(player.c));
	}
}

void mouseReleased() {
	if (player != null && MANUAL_CONTROL) {
		player.unGrab();
	}
}

void initWorlds() {
	trainWorlds = new ArrayList();
	for (int i = 0; i < TRAIN_WORLDS_SIZE; i++) {
		World w = new World();
		w.fillRandom(true);
		trainWorlds.add(w);
	}
	testWorlds = new ArrayList(trainWorlds);
	for (int i = 0; i < TEST_WORLDS_SIZE - TRAIN_WORLDS_SIZE; i++) {
        World w = new World();
        w.fillRandom(false);
        testWorlds.add(w);
    }
}

void resetView(World w) {
    if (isRunning) {
		//System.out.println("RESETTING");
    }
	gfxOffset += WORLD_SECTION_LENGTH;
	setupGfx(w, gfxOffset);
}

NeuralNetwork trainNet() throws PersistenceException {
	SimpleNeatParameters params = new SimpleNeatParameters();
	params.setFitnessFunction(new OMLFitnessFunction());
	params.setPopulationSize(POPULATION_SIZE);
	params.setMaximumFitness(OMLFitnessFunction.MAXIMUM_FITNESS);
	params.setMaximumGenerations(GENERATIONS_COUNT_MAX);

	NaturalSelectionOrganismSelector selector = new NaturalSelectionOrganismSelector();
	selector.setKillUnproductiveSpecies(true);
	selector.setElitismEnabled(true);
	selector.setSurvivalRatio(SURVIVAL_RATIO);
	params.setOrganismSelector(selector);

	ArrayList<NeuronGene> inputGenes = new ArrayList();
	for (int i = 0; i < NEURAL_NET_OBSTACLES_TOTAL * NEURAL_NET_VALUES_PER_OBSTACLE + NEURAL_NET_OTHER_VALUES; i++) {
		inputGenes.add(new NeuronGene(NeuronType.INPUT, params, NEURONS_SIGMOID_SLOPE));
	}
	ArrayList<NeuronGene> outputGenes = new ArrayList();
	outputGenes.add(new NeuronGene(NeuronType.OUTPUT, params, NEURONS_SIGMOID_SLOPE));

	Evolver evolver = null;
	try {
		evolver = Evolver.createNew(params, inputGenes, outputGenes);
	} 
	catch (Exception e) {
		System.out.println("ERROR START *****************");
        System.err.println(e.getMessage());
        System.err.println(Arrays.deepToString(e.getStackTrace()));
        System.out.println("ERROR END *******************");
	}
	Organism best = evolver.evolve();

	return params.getNeuralNetworkBuilder().createNeuralNetwork(best);
}

String netToString(NeuralNetwork network) {
	HashMap<Neuron, String> netMap = new HashMap<Neuron, String>();
	int layerCount = 0;
	int neuronCount;
	String outString = new String();
	for (Layer layer : network.getLayers()) {
		neuronCount = 0;
		for (Neuron neuron : layer.getNeurons()) {
			netMap.put(neuron, layerCount + ":" + neuronCount);
			neuronCount++;
		}
		layerCount++;
	}
	for (Layer layer : network.getLayers()) {
		for (Neuron neuron : layer.getNeurons()) {
			outString += "Neuron  " + netMap.get(neuron);
			if (neuron.getOutConnections().size() != 0) {
				outString += "  connects to";
				for (Connection connection : neuron.getOutConnections()) {
					outString += "  " + netMap.get(connection.getConnectedNeuron()) + "  weight  " + connection.getWeight();
				}
			} else {
				outString += "  Is output";
			}
			outString += "\n";
		}
	}
	return outString;
}

void updateGenInfo(double fitness) {
    if (playersSinceGeneration == POPULATION_SIZE) {
        playersSinceGeneration = 0;
        generation++;
        trainWorlds.remove(0);
        World w = new World();
        w.fillRandom(true);
        trainWorlds.add(w);
    }
    playersSinceGeneration++;
    if (fitness > globalMaxFitness) {
        globalMaxFitness = fitness;
    }
    if (fitness > localMaxFitness[generation]) {
        localMaxFitness[generation] = fitness;
    }
}

class OMLFitnessFunction extends AbstractFitnessFunction {
	static final int MAXIMUM_FITNESS = WORLD_LENGTH * TEST_WORLDS_SIZE;

	double evaluate (Organism o, NeuralNetwork nn) {
		boolean hasIdled = false;
		double highestScore = 0;
		double secondHighestScore = 0;
		double[] scores = new double[TRAIN_WORLDS_SIZE];
		long simulationBaseTime = System.currentTimeMillis();
    	for (int i = 0; i < trainWorlds.size(); i++) {
			Player player = new Player(INITIAL_PLAYER_X, INITIAL_PLAYER_Y, radians(INITIAL_PLAYER_ANGLE));
			player.world = trainWorlds.get(i);
			player.net = nn;
			RunResults results = runPlayer(player);
			if (results.turns > MAXIMUM_SIMULATION_TURNS) {
				//System.out.println("KILLED FOR EXCESS TIME");
				simulationTime += System.currentTimeMillis() - simulationBaseTime;
				return 1;    //I do not take kindly to mere machines wasting my valuable time
			}
			if (results.turnsGrabbed != 0 && results.turnsNotGrabbed != 0) {
				//netScore += results.score;
				scores[i] = results.score;
				if (scores[i] > highestScore) {
    				secondHighestScore = highestScore;
    				highestScore = scores[i];
    			} else if (scores[i] > secondHighestScore) {
        			secondHighestScore = scores[i];
        		}
				//System.out.println("********************");
			} else {
    			hasIdled = true;
				//System.out.println("Turns Taken: " + results.turns + ", Turns Grabbed: " + results.turnsGrabbed + ", Turns Not: " + results.turnsNotGrabbed);
			}
		}
		//System.out.println("Score: " + netScore + "  Hash: " + netToString(nn).hashCode());
		int netScore = 1;        //NOTE: This will break if the net score == zero, and probably if it is > 0.
		for (double score : scores) {
    		if (score == highestScore && highestScore > secondHighestScore * 2 && TRAIN_WORLDS_SIZE > 1) {
        		netScore += 2 * secondHighestScore;
        		//System.out.println("Score limited from " + highestScore + " to " + (secondHighestScore * 2));
        		continue;
    		}
    		netScore += score;
    	}
		if (hasIdled) {
    		netScore *= IDLE_SCORE_MULTIPLIER;
    	}
    	if (netScore < 1) {
        	netScore = 1;
    	}
		updateGenInfo(netScore);
		simulationTime  += System.currentTimeMillis() - simulationBaseTime;
		return netScore;
	}
}

//runs a single player forward in time, returning their ultimate y coordinate as a score
RunResults runPlayer(Player player) {
    long runTimeBase = System.currentTimeMillis();
	int turnsTaken = 0;
	int turnsGrabbed = 0;
	int turnsIdle = 0;
	while (player.alive) {
		MoveResults mvr = player.handleMove(turnsTaken);
		if (mvr.grabbed) {
    		turnsGrabbed++;
    	}
    	if (mvr.idle) {
        	turnsIdle++;
    	}
    	turnsTaken++;
	}
	runTime += System.currentTimeMillis() - runTimeBase;
	return new RunResults(turnsTaken, turnsGrabbed, turnsIdle, player.c.y);
}

class RunResults {
	public int turns;
	public int turnsGrabbed;
	public int turnsNotGrabbed;
	public double score;

	public RunResults(int turns, int turnsGrabbed, int turnsNotGrabbed, double score) {
		this.turns = turns;
		this.turnsGrabbed = turnsGrabbed;
		this.turnsNotGrabbed = turnsNotGrabbed;
		this.score = score;
	}
}

class MoveResults {
    public boolean grabbed;
    public boolean idle;

	public MoveResults(boolean grabbed, boolean idle) {
    	this.grabbed = grabbed;
    	this.idle = idle;
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

	public void resetPlayer(double x, double y, double angle) {
		resetPlayer(new Coordinate(x, y), angle);
	}

	public void resetPlayer(Coordinate c, double angle) {
		this.c = c;
		this.angle = angle;
		grabTarget = null;
		grabbedLast = false;
		alive = true;
	}

	public String toString() {
		return "Angle: " + radians((float)angle) + ", X: " + c.x + ", Y: " + c.y;
	}

	public void setNetworkInput() {
		if (world == null || net == null) {
			return;
		}
		ArrayList<Obstacle> obstacles = world.getNetObstacles(c);
		double[] networkInput = new double[NEURAL_NET_OBSTACLES_TOTAL * NEURAL_NET_VALUES_PER_OBSTACLE + NEURAL_NET_OTHER_VALUES];
		for (int i = 0; i < NEURAL_NET_OBSTACLES_TOTAL; i++) {
			if (obstacles.get(i) != null) {
				networkInput[i * NEURAL_NET_VALUES_PER_OBSTACLE] = obstacles.get(i).c.x - c.x;
				networkInput[i * NEURAL_NET_VALUES_PER_OBSTACLE + 1] = obstacles.get(i).c.y - c.y;
				networkInput[i * NEURAL_NET_VALUES_PER_OBSTACLE + 2] = obstacles.get(i).diameter / 2.0;
			} else {
				for (int j = 0; j < NEURAL_NET_VALUES_PER_OBSTACLE; j++) {
    				networkInput[i * NEURAL_NET_VALUES_PER_OBSTACLE + j] = NULL_OBSTACLE_VALUE;
    			}
			}
		}
		networkInput[NEURAL_NET_OBSTACLES_TOTAL * NEURAL_NET_VALUES_PER_OBSTACLE] = c.x - LEFT_LINE_X;
		networkInput[NEURAL_NET_OBSTACLES_TOTAL * NEURAL_NET_VALUES_PER_OBSTACLE + 1] = PLAYER_SPEED * sin((float)angle);
		networkInput[NEURAL_NET_OBSTACLES_TOTAL * NEURAL_NET_VALUES_PER_OBSTACLE + 2] = PLAYER_SPEED * cos((float)angle);
		net.setInput(networkInput);
		net.calculate();
	}

	//Handles one tick of movement for the player, including dying and grabbedLast;
	//returns if the player successfully grabbed a target
	public MoveResults handleMove(int turnCount) {
		boolean grabbed = false;        //wheither the player grabs on to anything
		boolean idle = true;			//wheither the player attempts to grab on to anything
		long moveTimeBase = System.currentTimeMillis();
		if (net != null) {
			setNetworkInput();
			networkTime += System.currentTimeMillis() - moveTimeBase;
			if (isRunning && PRINT_NET_OUTPUT) {
				System.out.println(net.getOutput());
			}
			if (net.getOutput().get(0) > NEURAL_NET_GRAB_THRESHOLD) {
				grabbed = grab(world.getClosestObstacle(c));
				idle = false;
			} else {
				unGrab();
			}
			obstacleTime += System.currentTimeMillis() - moveTimeBase;
		}
		moveTime0 += System.currentTimeMillis() - moveTimeBase;
		move();
		moveTime1 += System.currentTimeMillis() - moveTimeBase;
		drawPlayer();
		if ((checkCrash() && !NOCLIP) || c.y > WORLD_LENGTH || turnCount > MAXIMUM_SIMULATION_TURNS) {
			die();
			moveTime2 += System.currentTimeMillis() - moveTimeBase;
			return new MoveResults(grabbed, idle);
		}
		if (grabTarget == null) {        //whether the player successfully attempted to grab on to anything
			grabbedLast = false;
		} else {
			grabbedLast = true;
		}
		if (c.y - gfxOffset > WORLD_SECTION_LENGTH) {
			resetView(world);
		}
		moveTime2 += System.currentTimeMillis() - moveTimeBase;
		return new MoveResults(grabbed, idle);
	}

	//returns if successfully grabbed target
	public boolean grab(Obstacle target) {
		if (compareAngle(target)) {
			grabTarget = target;
			return true;
		}
		return false;
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
		if ((c.x < LEFT_LINE_X || c.x > RIGHT_LINE_X || c.y < 0) && grabTarget == null && grabbedLast == false) {
			//die();
			return true;
		}
		for (Obstacle o : world.obstacles) {
			if (o.containsPoint(c, PLAYER_DIAMETER / 2)) {
				//die();
				return true;
			}
		}
		return false;
	}

	public void die() {
		if (world.drawn) {
			fill(DEAD_PLAYER_RGB[0], DEAD_PLAYER_RGB[1], DEAD_PLAYER_RGB[2]);
			ellipse((float)c.x, (float)c.y - gfxOffset, PLAYER_DEATH_DIAMETER, PLAYER_DEATH_DIAMETER);
			fill(PLAYER_COLOR_BLANK, PLAYER_COLOR_BLANK, PLAYER_COLOR_BLANK);
		}
		alive = false;
	}

	private void grabMove() {
		double distance = sqrt(pow((float)grabTarget.c.y - (float)c.y, 2.0) + pow((float)grabTarget.c.x - (float)c.x, 2.0));
		double circumfrence = 2 * PI * distance;
		double relativeAngle = getRelativeAngle(grabTarget);
		double newRelativeAngle = relativeAngle;
		double angleChange = (TWO_PI * PLAYER_SPEED)/circumfrence;
		if (clockWise(grabTarget)) {
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
		while (newRelativeAngle < 0) {
			newRelativeAngle += TWO_PI;
		}
		while (newRelativeAngle >= TWO_PI) {
			newRelativeAngle -= TWO_PI;
		}
		while (angle < 0) {
			angle += TWO_PI;
		}
		while (angle >= TWO_PI) {
			angle -= TWO_PI;
		}
		double xOff = distance * cos((float)newRelativeAngle);
		double yOff = distance * sin((float)newRelativeAngle);
		c = new Coordinate(grabTarget.c.x + xOff, grabTarget.c.y + yOff);
		//System.out.println("Distance: " + distance + ", Relative angle: " + degrees((float)relativeAngle) + ", Angle change: " + degrees((float)angleChange) + ", New Relative Angle: " + degrees((float)newRelativeAngle) + ", Angle: " + degrees((float)angle) + ", xOff: " + xOff + ", yOff: " + yOff);
	}

	//determines if player should or should not rotate clockwise about the given target object
	public boolean clockWise(Obstacle o) {
		double relativeAngle = getRelativeAngle(o);
		double clockwiseTangent = relativeAngle + HALF_PI;
		double counterclockwiseTangent = relativeAngle - HALF_PI;
		if (clockwiseTangent > TWO_PI) {
			clockwiseTangent -= TWO_PI;
		}
		if (counterclockwiseTangent < 0) {
			counterclockwiseTangent += TWO_PI;
		}
		double clockTangentComp = abs((float)angle - (float)clockwiseTangent);
		double counterTangentComp = abs((float)angle - (float)counterclockwiseTangent);
		if (clockTangentComp > 180) {
			clockTangentComp = 360 - clockTangentComp;
		}
		if (counterTangentComp > 180) {
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

	public double getRelativeAngle(Obstacle o) {                        //returns in radians, 0-360 degree format
		double retVal = atan2((float)(c.y - o.c.y), (float)(c.x - o.c.x));
		//System.out.println("xOff: " + (c.x - o.c.x) + ", yOff: " + (c.y - o.c.y) + ", Relative angle: " + retVal);
		if (retVal < 0) {
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
		if (world.drawn) {
			if (grabTarget != null) {
				line((float)c.x, (float)c.y - gfxOffset, (float)grabTarget.c.x, (float)grabTarget.c.y - gfxOffset);
				fill(PLAYER_COLOR_SUCCESSFUL_GRAB);
			} else if (net != null && net.getOutput().get(0) > NEURAL_NET_GRAB_THRESHOLD) {
    			fill(PLAYER_COLOR_ATTEMPTED_GRAB);
    		}
			ellipse((float)c.x, (float)c.y - gfxOffset, (float)PLAYER_DIAMETER, (float)PLAYER_DIAMETER);
			fill(PLAYER_COLOR_BLANK);
		}
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

	public Obstacle getClosestObstacle(Coordinate coord) {
		return getClosestObstacles(coord).get(0);
	}

	public ArrayList<Obstacle> getClosestObstacles(Coordinate coord) {
		ArrayList<Obstacle> obsArray = new ArrayList(obstacles);
		final Coordinate c = coord;
		Collections.sort(obsArray, new Comparator<Obstacle>() {
			public int compare(Obstacle o1, Obstacle o2) {
				return o1.distanceTo(c) < o2.distanceTo(c) ? -1 : o1.distanceTo(c) == o2.distanceTo(c) ? 0 : 1;
			}
		}
		);
		return obsArray;
	}

	//gets the relevant obstacles for a given coordinate
	//the obstacle before and the four after the given location
	//if any of these don't exist, the value at that index will be null
	//TODO: OPTIMIZE THIS ITS TERRIBLE
	public ArrayList<Obstacle> getNetObstacles(Coordinate c) {
		ArrayList<Obstacle> netObs = new ArrayList();
		//add in valid after objects and before object, valid or not
		for (int i = 0; i < obstacles.size(); i++) {
			if (netObs.size() == NEURAL_NET_OBSTACLES_TOTAL) {
				break;
			}
			if (obstacles.get(i).c.y > c.y && netObs.size() == 0) {
				if (i == 0) {
					netObs.add(null);
				} else {
					netObs.add(obstacles.get(i-1));
				}
				i--;
				continue;            //to ensure functionality in the event of 0 forward obstacles given
			}
			if (obstacles.get(i).c.y > c.y) {
				netObs.add(obstacles.get(i));
			}
		}
		//add in invalid after objects
		while (netObs.size() < NEURAL_NET_OBSTACLES_TOTAL) {
			netObs.add(null);
		}
		return netObs;
	}

	public void fillRandom(boolean trainWorld) {
		int obstaclesAdded = 0;
		for (int i = OBSTACLES_Y_START; i < OBSTACLES_Y_END; i += OBSTACLES_INTERVAL, obstaclesAdded++) {
			obstacles.add(new Obstacle(
			/*
			 * excessively long conditional behavior as follows:
			 * obstaclesAdded > GAP_OBSTACLES : (r.nextInt(RIGHT_LINE_X - LEFT_LINE_X) + LEFT_LINE_X)
			 * obstaclesAdded == GAP_OBSTACLES : (LEFT_LINE_X + RIGHT_LINE_X) / 2.0
			 * obstaclesAdded < GAP_OBSTACLES : r.nextInt((RIGHT_LINE_X - LEFT_LINE_X - GAP_WIDTH) / 2) + LEFT_LINE_X + ((RIGHT_LINE_X - LEFT_LINE_X - GAP_WIDTH) / 2 + GAP_WIDTH) * r.nextInt(1)
			 */
			obstaclesAdded > 2 ? (r.nextInt(RIGHT_LINE_X - LEFT_LINE_X) + LEFT_LINE_X) : obstaclesAdded == 2 ? (LEFT_LINE_X + RIGHT_LINE_X) / 2.0 : r.nextInt((RIGHT_LINE_X - LEFT_LINE_X - GAP_WIDTH) / 2) + LEFT_LINE_X + ((RIGHT_LINE_X - LEFT_LINE_X - GAP_WIDTH) / 2 + GAP_WIDTH) * r.nextInt(2), 
			r.nextInt(OBSTACLES_INTERVAL) + i, 
			r.nextInt(OBSTACLES_SIZE_RANGE) + OBSTACLES_MIN_SIZE));
			//if (obstaclesAdded == GAP_OBSTACLES && trainWorld) {
    			//Obstacle ob = obstacles.get(GAP_OBSTACLES);
    			//baseScore += ob.c.y;
    			
    		//}
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

	public void drawObstacle(int offset) {
		ellipse((float)c.x, (float)c.y - offset, (float)diameter, (float)diameter);
	}

	public boolean containsPoint(Coordinate p, double offset) {
		return sqrt(pow((float)p.x - (float)c.x, 2) + pow((float)p.y - (float)c.y, 2)) < diameter / 2 + offset;
	}

	public double distanceTo(Coordinate loc) {
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
