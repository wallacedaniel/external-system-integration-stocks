public class ExternalSystemNotifier {
    
    // Method to send weather alerts to external system
    public static void sendWeatherAlert(Weather_Data__c weatherData, String alertType) {
        try {
            API_Configuration__mdt config = [SELECT Base_URL__c, API_Key__c, Timeout__c 
                                             FROM API_Configuration__mdt 
                                             WHERE DeveloperName = 'Notification_API' AND Active__c = true 
                                             LIMIT 1];
            
            // Get office location details
            Office_Location__c location = [
                SELECT Id, Name, City__c, Country__c 
                FROM Office_Location__c 
                WHERE Id = :weatherData.Office_Location__c
            ];
            
            // Prepare the payload
            Map<String, Object> payload = new Map<String, Object>{
                'locationName' => location.Name,
                'city' => location.City__c,
                'country' => location.Country__c,
                'weatherCondition' => weatherData.Weather_Condition__c,
                'temperature' => weatherData.Temperature__c,
                'windSpeed' => weatherData.Wind_Speed__c,
                'humidity' => weatherData.Humidity__c,
                'alertType' => alertType,
                'timestamp' => Datetime.now().getTime(),
                'source' => 'Salesforce'
            };
            
            String jsonPayload = JSON.serialize(payload);
            
            // Prepare callout
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint(config.Base_URL__c + '/alerts');
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/json');
            request.setHeader('x-api-key', config.API_Key__c);
            request.setBody(jsonPayload);
            request.setTimeout(Integer.valueOf(config.Timeout__c));
            
            // Log request
            String requestLog = 'POST ' + request.getEndpoint() + ' ' + jsonPayload;
            
            // Make the callout
            HttpResponse response = http.send(request);
            
            // Process response
            if(response.getStatusCode() == 200 || response.getStatusCode() == 201) {
                logIntegration('Outbound', 'Success', requestLog, response.getBody());
            } else {
                logIntegration('Outbound', 'Error', requestLog, response.getBody(), 'HTTP Status: ' + response.getStatusCode());
                throw new CalloutException('Notification API returned: ' + response.getStatusCode() + ' ' + response.getStatus());
            }
        } catch(Exception e) {
            logIntegration('Outbound', 'Error', 'sendWeatherAlert', null, e.getMessage());
        }
    }
    
    // Helper method to log integration activity
    private static void logIntegration(String type, String status, String request, String response, String error) {
        Integration_Log__c log = new Integration_Log__c(
            Integration_Type__c = type,
            Status__c = status,
            Request__c = request,
            Response__c = response,
            Error_Message__c = error,
            Created_Date__c = Datetime.now()
        );
        
        insert log;
    }
    
    private static void logIntegration(String type, String status, String request, String response) {
        logIntegration(type, status, request, response, null);
    }
}