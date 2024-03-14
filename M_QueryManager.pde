import java.util.Arrays;
import java.util.concurrent.atomic.AtomicInteger;

class QueryManagerClass {
  Table m_airlineTable;
  Table m_airportTable;
  TableRow m_lookupResult;
  private boolean m_working;

  void init() {
    m_airlineTable = loadTable(sketchPath() + DATA_DIRECTOR_PATH + "airlines.csv", "header");
    m_airportTable = loadTable(sketchPath() + DATA_DIRECTOR_PATH + "airports.csv", "header");
    if (m_airportTable == null || m_airlineTable == null) {
      println("ERROR ON INIT QUERY MANAGER");
    }

  }
  //a series of function for lookup tables - the lookup tables are loaded directly into processing as spreadsheets
  //the findRow functions allow the spreadsheet to be searched, and a pointer to that row is passed as a variable
  float getLatitude(String code) {
    m_lookupResult = m_airportTable.findRow(code, "IATA");
    //if (m_lookupResult == null)
    //  return 0;
    return m_lookupResult.getFloat("Latitude");
  }
  float getLongitude(String code) {
    m_lookupResult = m_airportTable.findRow(code, "IATA");
    //if (m_lookupResult == null)
    //  return 0;   
    return m_lookupResult.getFloat("Longitude");
  }
  String getAirportName(String code) {
    m_lookupResult = m_airportTable.findRow(code, "IATA");
    return m_lookupResult.getString("Name");
  }
  String getCity(String code) {
    m_lookupResult = m_airportTable.findRow(code, "IATA");
    return m_lookupResult.getString("City");
  }
  String getCountry(String code) {
    m_lookupResult = m_airportTable.findRow(code, "IATA");
    return m_lookupResult.getString("Country");
  }
  String getCode(int index) {
    m_lookupResult = m_airportTable.findRow(String.valueOf(index), "Key");
    return m_lookupResult.getString("IATA");
  }
  int getIndex(String code) {
    m_lookupResult = m_airportTable.findRow(code, "IATA");
    return m_lookupResult.getInt("Key");
  }
  String getAirlineCode(int airlineIndex) {
    m_lookupResult = m_airlineTable.findRow(String.valueOf(airlineIndex), "Key");
    return m_lookupResult.getString("IATA");
  }
  String getAirlineName(int airlineIndex) {
    m_lookupResult = m_airlineTable.findRow(String.valueOf(airlineIndex), "Key");
    return m_lookupResult.getString("Airline");
  }
  
  public void queryFlights(FlightType[] flightsList, FlightQuery flightQuery, int queryValue, int threadCount, Consumer<FlightType[]> onTaskComplete) {
    println("+Query Start");
    if (m_working) {
      println("Warning: m_working is true, queryFlights did not process correctly");
      return;
    }

    new Thread(() -> {
      s_DebugProfiler.startProfileTimer();
      FlightType[] newFlightsList = queryFlightsAysnc(flightsList, flightQuery, queryValue, threadCount);
      s_DebugProfiler.printTimeTakenMillis("queryFlights");
      
      println("+Query Lambda Call");
      m_working = false;
      onTaskComplete.accept(newFlightsList);
    }
    ).start();

    m_working = true;
    return;
  }
  private FlightType[] queryFlightsAysnc(FlightType[] flightsList, FlightQuery flightQuery, int queryValue, int threadCount) {
    ExecutorService executor = Executors.newFixedThreadPool(threadCount);
    CountDownLatch latch = new CountDownLatch(threadCount);

    if (!checkForIllegalQuery(flightQuery)) {
      println("Error: FlightQuery.Type is illegal with FlightQuery.Operator");
      return flightsList;
    }
    int chunkSize = NUMBER_OF_FLIGHT_FULL_LINES / threadCount;
    ArrayList<FlightType[]> listOfFlightsLists = new ArrayList<>();
    println("+Starting Query Chunks");

    for (int i = 0; i < threadCount; i++) {
      int startPosition = i * chunkSize;
      long endPosition = (i == threadCount - 1) ? NUMBER_OF_FLIGHT_FULL_LINES : (i + 1) * chunkSize;

      executor.submit(() -> {
        println("+Query Executor Start");
        listOfFlightsLists.add(processQueryFlightsChunk(Arrays.copyOfRange(flightsList, startPosition, (int)endPosition), flightQuery, queryValue));
        println("+Query Executor End");
        latch.countDown();
      }
      );
    }
    try {
      println("+Waiting for latches to finish");
      latch.await();
    }
    catch (InterruptedException e) {
      e.printStackTrace();
    }
    executor.shutdown();
    FlightType[] joinedFlightArray = listOfFlightsLists.stream()
      .flatMap(Arrays::stream)
      .toArray(FlightType[]::new);
    println("+Query Executor Shutdown");
    return joinedFlightArray;
  }
  private FlightType[] processQueryFlightsChunk(FlightType[] flightsList, FlightQuery flightQuery, int queryValue) {
    println("+Query Chunk Starting Now " + queryValue + " " + flightQuery);
    switch(flightQuery.Operator) {
    case EQUAL:
      println("+EQUAL case found");
      return Arrays.stream(flightsList)
        .filter(flight -> getFlightTypeFieldFromQueryType(flight, flightQuery.Type) == queryValue)
        .toArray(FlightType[]::new);
        //return Arrays.stream(flightsList)
        //.filter(flight -> getFlightTypeFieldFromQueryType(flight, flightQuery.Type) == queryValue)
        //.toArray(FlightType[]::new);
    case NOT_EQUAL:
      return Arrays.stream(flightsList)
        .filter(flight -> getFlightTypeFieldFromQueryType(flight, flightQuery.Type) != queryValue)
        .toArray(FlightType[]::new);
    case LESS_THAN:
      return Arrays.stream(flightsList)
        .filter(flight -> getFlightTypeFieldFromQueryType(flight, flightQuery.Type) < queryValue)
        .toArray(FlightType[]::new);
    case LESS_THAN_EQUAL:
      return Arrays.stream(flightsList)
        .filter(flight -> getFlightTypeFieldFromQueryType(flight, flightQuery.Type) <= queryValue)
        .toArray(FlightType[]::new);
    case GREATER_THAN:
      return Arrays.stream(flightsList)
        .filter(flight -> getFlightTypeFieldFromQueryType(flight, flightQuery.Type) > queryValue)
        .toArray(FlightType[]::new);
    case GREATER_THAN_EQUAL:
      return Arrays.stream(flightsList)
        .filter(flight -> getFlightTypeFieldFromQueryType(flight, flightQuery.Type) >= queryValue)
        .toArray(FlightType[]::new);
    default:
      println("Error: FlightQuery.Operator invalid");
      return flightsList;
    }
  }
  public void queryFlightsWithinRange(FlightType[] flightsList, FlightRangeQuery flightRangeQuery, int start, int end, int threadCount, Consumer<FlightType[]> onTaskComplete) {
    if (m_working) {
      println("Warning: m_working is true, queryFlightsWithinRange did not process correctly");
      return;
    }

    new Thread(() -> {
      s_DebugProfiler.startProfileTimer();
      FlightType[] newFlightsList = queryFlightsWithinRangeAysnc(flightsList, flightRangeQuery, start, end, threadCount);
      s_DebugProfiler.printTimeTakenMillis("queryFlightsWithinRange");

      m_working = false;
      onTaskComplete.accept(newFlightsList);
    }
    ).start();

    m_working = true;
    return;
  }
  private FlightType[] queryFlightsWithinRangeAysnc(FlightType[] flightsList, FlightRangeQuery flightRangeQuery, int start, int end, int threadCount) {
    ExecutorService executor = Executors.newFixedThreadPool(threadCount);
    CountDownLatch latch = new CountDownLatch(threadCount);

    if (!checkForIllegalQuery(flightRangeQuery)) {
      println("Error: FlightRangeQuery.Type is illegal to query range");
      return flightsList;
    }

    int chunkSize = NUMBER_OF_FLIGHT_FULL_LINES / threadCount;
    ArrayList<FlightType[]> listOfFlightsLists = new ArrayList<>();

    for (int i = 0; i < threadCount; i++) {
      int startPosition = i * chunkSize;
      long endPosition = (i == threadCount - 1) ? NUMBER_OF_FLIGHT_FULL_LINES : (i + 1) * chunkSize;

      executor.submit(() -> {
        listOfFlightsLists.add(processQueryFlightsWithinRangeChunk(Arrays.copyOfRange(flightsList, startPosition, (int)endPosition), flightRangeQuery, start, end));
        latch.countDown();
      }
      );
    }
    try {
      latch.await();
    }
    catch (InterruptedException e) {
      e.printStackTrace();
    }
    executor.shutdown();
    FlightType[] joinedFlightArray = listOfFlightsLists.stream()
      .flatMap(Arrays::stream)
      .toArray(FlightType[]::new);
    return joinedFlightArray;
  }
  private FlightType[] processQueryFlightsWithinRangeChunk(FlightType[] flightsList, FlightRangeQuery flightRangeQuery, int start, int end) {
    return Arrays.stream(flightsList)
      .filter(flight -> getFlightTypeFieldFromQueryType(flight, flightRangeQuery.Type) >= start &&
      getFlightTypeFieldFromQueryType(flight, flightRangeQuery.Type) < end)
      .toArray(FlightType[]::new);
  }
  private int getFlightTypeFieldFromQueryType(FlightType flight, QueryType queryType) {
    switch(queryType) {
    case DAY:
      return (int)flight.Day;
    case CARRIER_CODE_INDEX:
      return (int)flight.CarrierCodeIndex;
    case FLIGHT_NUMBER:
      return (int)flight.FlightNumber;
    case AIRPORT_ORIGIN_INDEX:
      return (int)flight.AirportOriginIndex;
    case AIRPORT_DEST_INDEX:
      return (int)flight.AirportDestIndex;
    case SCHEDULED_DEPARTURE_TIME:
      return (int)flight.ScheduledDepartureTime;
    case DEPARTURE_TIME:
      return (int)flight.DepartureTime;
    case SCHEDULED_ARRIVAL_TIME:
      return (int)flight.ScheduledArrivalTime;
    case ARRIVAL_TIME:
      return (int)flight.ArrivalTime;
    case CANCELLED_OR_DIVERTED:
      return (int)flight.CancelledOrDiverted;
    case KILOMETRES_DISTANCE:
      return (int)flight.MilesDistance;
    default:
      println("Error: Query.Type invalid");
      return -1;
    }
  }
  private boolean checkForIllegalQuery(FlightQuery flightQuery) {
    if (flightQuery.Location == QueryLocation.US) {
      switch(flightQuery.Type) {
      case CARRIER_CODE_INDEX:
      case FLIGHT_NUMBER:
      case AIRPORT_ORIGIN_INDEX:
      case AIRPORT_DEST_INDEX:
      case CANCELLED_OR_DIVERTED:
        if (flightQuery.Operator == QueryOperator.EQUAL || flightQuery.Operator == QueryOperator.NOT_EQUAL) {
          return true;
        } else {
          return false;
        }
      default:
        return true;
      }
    } else {
      switch(flightQuery.Type) {
      case CARRIER_CODE_INDEX:
      case AIRPORT_ORIGIN_INDEX:
      case AIRPORT_DEST_INDEX:
        if (flightQuery.Operator == QueryOperator.EQUAL || flightQuery.Operator == QueryOperator.NOT_EQUAL) {
          return true;
        }
      default:
        return false;
      }
    }
  }
  private boolean checkForIllegalQuery(FlightRangeQuery flightRangeQuery) {
    if (flightRangeQuery.Location == QueryLocation.US) {
      switch(flightRangeQuery.Type) {
      case CARRIER_CODE_INDEX:
      case FLIGHT_NUMBER:
      case AIRPORT_ORIGIN_INDEX:
      case AIRPORT_DEST_INDEX:
      case CANCELLED_OR_DIVERTED:
        return false;
      default:
        return true;
      }
    } else {
      return false;
    }
  }
  public FlightType[] sort(FlightType[] flightsList, FlightSortQuery flightSortQuery) {
    Comparator<FlightType> flightComparator;
    switch(flightSortQuery.Type) {
    case DAY:
      flightComparator = Comparator.comparingInt(flight -> flight.Day);
      break;
    case CARRIER_CODE_INDEX:
      flightComparator = Comparator.comparingInt(flight -> flight.CarrierCodeIndex);
      break;
    case FLIGHT_NUMBER:
      flightComparator = Comparator.comparingInt(flight -> flight.FlightNumber);
      break;
    case AIRPORT_ORIGIN_INDEX:
      flightComparator = Comparator.comparingInt(flight -> flight.AirportOriginIndex);
      break;
    case AIRPORT_DEST_INDEX:
      flightComparator = Comparator.comparingInt(flight -> flight.AirportDestIndex);
      break;
    case SCHEDULED_DEPARTURE_TIME:
      flightComparator = Comparator.comparingInt(flight -> flight.ScheduledDepartureTime);
      break;
    case DEPARTURE_TIME:
      flightComparator = Comparator.comparingInt(flight -> flight.DepartureTime);
      break;
    case SCHEDULED_ARRIVAL_TIME:
      flightComparator = Comparator.comparingInt(flight -> flight.ScheduledArrivalTime);
      break;
    case ARRIVAL_TIME:
      flightComparator = Comparator.comparingInt(flight -> flight.ArrivalTime);
      break;
    case CANCELLED_OR_DIVERTED:
      flightComparator = Comparator.comparingInt(flight -> flight.CancelledOrDiverted);
      break;
    case KILOMETRES_DISTANCE:
      flightComparator = Comparator.comparingInt(flight -> flight.MilesDistance);
      break;
    default:
      println("Error: FlightSortQuery.Type invalid");
      return flightsList;
    }
    switch(flightSortQuery.SortDirection) {
    case ASCENDING:
      break;
    case DESCENDING:
      flightComparator = flightComparator.reversed();
      break;
    default:
      println("Error: FlightSortQuery.SortDirection invalid");
      return flightsList;
    }

    Arrays.sort(flightsList, flightComparator);
    return flightsList;
  }
  public int queryFrequency(FlightType[] flightsList, FlightQuery flightQuery, int queryValue, int threadCount) {
    AtomicInteger frequency = new AtomicInteger(0);
    queryFlights(flightsList, flightQuery, queryValue, threadCount, returnedList -> {
      frequency.set(returnedList.length);
    }
    );
    return frequency.get();
  }
  public int queryRangeFrequency(FlightType[] flightsList, FlightRangeQuery flightRangeQuery, int start, int end, int threadCount) {
    AtomicInteger frequency = new AtomicInteger(0);
    queryFlightsWithinRange(flightsList, flightRangeQuery, start, end, threadCount, returnedList -> {
      frequency.set(returnedList.length);
    }
    );
    return frequency.get();
  }
  public FlightType[] getHead(FlightType[] flightList, int numberOfItems) {
    return Arrays.copyOfRange(flightList, 0, numberOfItems);
  }
  public FlightType[] getFoot(FlightType[] flightList, int numberOfItems) {
    return Arrays.copyOfRange(flightList, numberOfItems, flightList.length);
  }
  public FlightType[] getWithinRange(FlightType[] flightList, int start, int end) {
    return Arrays.copyOfRange(flightList, start, end);
  }
}

// Descending code authorship changes:
// CKM: wrote class to return details about airports 17:00 11/03
// T. Creagh, moved query methods in, 11pm 06/03/24
// T. Creagh, fixed queryFrequency and queryRangeFrequency, 12pm 06/03/24
// T. Creagh, removed redundant code, 12:30pm 06/03/24
// CKM, wrote comments about my code, 16:00 12/03
// CKM, converted to kilometres 17:00 12/03
// T. Creagh, Added Working queryFlights with world, 10pm, 12/03/24
// T. Creagh, Added Working queryRangeFlights with world, 11pm, 12/03/24
// T. Creagh, Added Working querySortFlights with world, 11:30pm, 12/03/24
// T. Creagh, Added Working queryFrequency with world, 11:45pm, 12/03/24
// T. Creagh, Added Working queryRangeFrequency with world, 12pm, 12/03/24
// CKM, added world lookup functions 13:00 14/03
// CKM, added airline lookup functions 13:00 14/03
