public class StockPriceService {
    
    // Get API configuration from custom metadata
    private static API_Configuration__mdt getAPIConfiguration() {
        return [SELECT Base_URL__c, API_Key__c, Timeout__c 
                FROM API_Configuration__mdt 
                WHERE DeveloperName = 'Stock_API' AND Active__c = true 
                LIMIT 1];
    }
    
    // Method to get current stock price for a holding
    @AuraEnabled
    public static Map<String, Object> getStockPrice(Id holdingId) {
        try {
            // Get stock holding details
            Stock_Holding__c holding = [
                SELECT Id, Name, Company_Name__c, Current_Price__c, Client_Portfolio__c
                FROM Stock_Holding__c 
                WHERE Id = :holdingId
            ];
            
            // Make callout to get current price
            Map<String, Object> stockData = makeStockPriceCallout(holding.Name); // Name field contains the stock symbol
            
            // Update the stock holding with new price data
            updateStockHolding(stockData, holding);
            
            // Return data to caller
            return stockData;
        } catch(Exception e) {
            logIntegration('Inbound', 'Error', 'getStockPrice: ' + holdingId, null, e.getMessage());
            throw new AuraHandledException('Error getting stock price data: ' + e.getMessage());
        }
    }
    
    // Method to update all active stock holdings
    public static void updateAllStockHoldings() {
        try {
            // Get all stock holdings from active portfolios
            List<Stock_Holding__c> holdings = [
                SELECT Id, Name, Company_Name__c, Current_Price__c, Client_Portfolio__c
                FROM Stock_Holding__c 
                WHERE Client_Portfolio__r.Active__c = true
            ];
            
            // Process each holding
            for(Stock_Holding__c holding : holdings) {
                try {
                    Map<String, Object> stockData = makeStockPriceCallout(holding.Name);
                    updateStockHolding(stockData, holding);
                } catch(Exception e) {
                    logIntegration('Inbound', 'Error', 'updateAllStockHoldings: ' + holding.Id, null, e.getMessage());
                    // Continue processing other holdings even if one fails
                }
            }
        } catch(Exception e) {
            logIntegration('Inbound', 'Error', 'updateAllStockHoldings batch', null, e.getMessage());
        }
    }
    
    // Helper method to make the actual API callout
    private static Map<String, Object> makeStockPriceCallout(String stockSymbol) {
        API_Configuration__mdt config = getAPIConfiguration();
        
        // Prepare callout
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(config.Base_URL__c + '/quote?symbol=' + stockSymbol + '&apikey=' + config.API_Key__c);
        request.setMethod('GET');
        request.setTimeout(Integer.valueOf(config.Timeout__c));
        
        // Log request
        String requestLog = 'GET ' + request.getEndpoint().replace(config.API_Key__c, 'API_KEY_REDACTED');
        
        // Make the callout
        HttpResponse response = http.send(request);
        
        // Process response
        if(response.getStatusCode() == 200) {
            Map<String, Object> stockData = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            logIntegration('Inbound', 'Success', requestLog, JSON.serialize(stockData));
            return stockData;
        } else {
            logIntegration('Inbound', 'Error', requestLog, response.getBody(), 'HTTP Status: ' + response.getStatusCode());
            throw new CalloutException('Stock API returned: ' + response.getStatusCode() + ' ' + response.getStatus());
        }
    }
    
    // Helper method to update stock holding with new price data
    private static void updateStockHolding(Map<String, Object> stockData, Stock_Holding__c holding) {
        // Extract relevant data from API response
        Decimal currentPrice = (Decimal)stockData.get('price');
        String companyName = (String)stockData.get('name');
        
        // Update the stock holding record
        holding.Current_Price__c = currentPrice;
        if(holding.Company_Name__c == null) {
            holding.Company_Name__c = companyName;
        }
        holding.Last_Updated__c = Datetime.now();
        
        update holding;
        
        // Check for significant price changes and notify external system if needed
        checkAndNotifyPriceChange(holding, currentPrice);
    }
    
    // Helper method to log integration activity
    private static void logIntegration(String type, String status, String request) {
        logIntegration(type, status, request, null, null);
    }
    
    private static void logIntegration(String type, String status, String request, String response) {
        logIntegration(type, status, request, response, null);
    }
    
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
    
    // Method to check if price change is significant and send notification to external system
    private static void checkAndNotifyPriceChange(Stock_Holding__c holding, Decimal newPrice) {
        // Calculate percentage change if we have a purchase price
        if(holding.Purchase_Price__c != null && holding.Purchase_Price__c > 0) {
            Decimal changePercentage = ((newPrice - holding.Purchase_Price__c) / holding.Purchase_Price__c) * 100;
            
            // Define significant price changes (customize as needed)
            Boolean isSignificant = false;
            String changeType = '';
            
            if(changePercentage >= 10) {
                isSignificant = true;
                changeType = 'Major Gain';
            } else if(changePercentage <= -10) {
                isSignificant = true;
                changeType = 'Major Loss';
            } else if(changePercentage >= 5) {
                isSignificant = true;
                changeType = 'Significant Gain';
            } else if(changePercentage <= -5) {
                isSignificant = true;
                changeType = 'Significant Loss';
            }
            
            if(isSignificant) {
                // Send notification to external system
                ExternalSystemNotifier.sendPriceAlert(holding, newPrice, changePercentage, changeType);
            }
        }
    }
}