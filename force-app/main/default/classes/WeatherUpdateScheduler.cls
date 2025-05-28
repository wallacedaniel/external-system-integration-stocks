global class WeatherUpdateScheduler implements Schedulable {
    global void execute(SchedulableContext SC) {
        // Get all active office locations
        List<Office_Location__c> activeLocations = [
            SELECT Id, Latitude__c, Longitude__c 
            FROM Office_Location__c 
            WHERE Active__c = true
        ];
        
        if (activeLocations.isEmpty()) {
            return;
        }
        
        // Process each location
        for (Office_Location__c location : activeLocations) {
            try {
                WeatherService.getWeatherForLocation(location.Id);
            } catch (Exception e) {
                // Log error but continue with other locations
                Integration_Log__c log = new Integration_Log__c(
                    Integration_Type__c = 'Weather_API',
                    Status__c = 'Error',
                    Request__c = 'Scheduled update for ' + location.Name,
                    Response__c = e.getMessage(),
                    Error_Message__c = e.getMessage()
                );
                insert log;
            }
        }
    }
}
