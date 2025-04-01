Salesforce Weather and Stock Integration
Overview
This project demonstrates a comprehensive API integration system between Salesforce and external services, featuring two main components:

Weather Tracking System

Pulls weather data for office locations
Sends notifications for extreme weather events
Scheduled and on-demand updates


Stock Portfolio Management

Real-time stock price updates
Price change notifications
REST API for external system integration



Custom Objects
Office_Location__c

Tracks office locations with geographic coordinates
Fields: Name, City__c, Country__c, Latitude__c, Longitude__c, Active__c

Weather_Data__c

Stores weather conditions for office locations
Fields: Office_Location__c, Temperature__c, Weather_Condition__c, Humidity__c, Wind_Speed__c, Last_Updated__c, Weather_Date__c, Is_Extreme_Weather__c

Stock_Holding__c

Manages stock portfolio entries
Fields: Name (Stock Symbol), Company_Name__c, Current_Price__c, Purchase_Price__c, Quantity__c, Client_Portfolio__c, Last_Updated__c

Integration_Log__c

Comprehensive logging system for all API interactions
Fields: Integration_Type__c, Status__c, Request__c, Response__c, Error_Message__c, Created_Date__c

Core Classes
ExternalSystemNotifier.cls
Handles outbound notifications to external systems for weather alerts and price changes, leveraging custom metadata for API configuration.
StockPriceService.cls
Manages stock price updates through API integration, featuring:

Individual and batch stock updates
Significant price change detection
Comprehensive error handling and logging

StockPriceUpdateScheduler.cls
Scheduled Apex job that periodically updates all stock holdings with current market data.
StockRestService.cls
REST API implementation that allows external systems to:

Retrieve stock holding information
Create new stock holdings
Includes proper request validation and error handling

Implementation Highlights
API Integration Best Practices

Custom Metadata Types for configuration management
Comprehensive exception handling
Detailed request/response logging
Timeout handling

Security Features

API key management
Sensitive data redaction in logs
Input validation

Performance Considerations

Batch processing for multiple records
Graceful error handling to prevent batch failures

Installation

Deploy the following components:

Apex Classes (ExternalSystemNotifier.cls, StockPriceService.cls, StockPriceUpdateScheduler.cls, StockRestService.cls)
Custom Objects (Office_Location__c, Weather_Data__c, Stock_Holding__c, Integration_Log__c)
Custom Metadata Type (API_Configuration__mdt)


Configure API settings in Custom Metadata:

Create records for Notification_API and Stock_API
Set Base_URL__c, API_Key__c, and Timeout__c values


Schedule the stock price update job:

apexCopyString cronExp = '0 0 18 * * ?'; // Daily at 6 PM
System.schedule('Daily Stock Updates', cronExp, new StockPriceUpdateScheduler());
Usage Examples
Getting Current Stock Price
apexCopyMap<String, Object> stockData = StockPriceService.getStockPrice(holdingId);
Creating a REST API Request
httpCopyPOST /services/apexrest/stocks/v1
Content-Type: application/json

{
  "portfolioId": "a01xx0000012gZZAAA",
  "symbol": "AAPL",
  "companyName": "Apple Inc.",
  "quantity": 100,
  "purchasePrice": 150.25
}
License
MIT License