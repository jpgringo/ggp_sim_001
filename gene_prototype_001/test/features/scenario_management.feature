Feature: Serve coffee
  Coffee should not be served until paid for
  Coffee should not be served until the button has been pressed
  If there is no coffee left then money should be refunded

  Scenario: Create a scenario
    Given The HTTP service is available
#    And No scenario with the "resource_id" nil and id "FOOBAR123" exists
#    When I pass those scenario variables
#    And I specify 3 agents with 2 sensors and 1 actuator each
    Then Server status should be true
#    Then The scenario should be created
#    And The 3 Onta should be associated with it
