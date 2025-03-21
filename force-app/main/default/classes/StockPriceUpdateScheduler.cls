global class StockPriceUpdateScheduler implements Schedulable {
    global void execute(SchedulableContext ctx) {
        StockPriceService.updateAllStockHoldings();
    }
}