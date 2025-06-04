Feature: Create Scenarios
  Scenarios should be creatable from JSON payloads
  The JSON payload should specify the scenario resource id and a unique id
  The payload should additionally provide a list of agents, specifying unique id and actuator count
  A full supervision tree should be created, representing the simulation scenario
  The supervision tree should include a Scenario and the required Onta

  Scenario: Create a scenario
    Given The HTTP service is available
    And No scenario with the resource id nil and run id "FOOBAR123" exists
    When I pass those scenario variables
    And I specify 3 agents with 2 sensors and 1 actuators each
    Then Server status should be true
    Then The scenario should be created
    And 3 Onta should be associated with the scenario
