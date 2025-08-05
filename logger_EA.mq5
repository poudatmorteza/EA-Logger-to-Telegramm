//+------------------------------------------------------------------+
//|                                                          logger.mq5 |
//|                             Copyright 2025, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Comprehensive Trading Logger EA with Telegram Notifications v1.02"

// Include required files
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include <Trade\DealInfo.mqh>

// Enumerations
enum ENUM_LOG_LEVEL
{
   LOG_NONE = 0,      // No logging
   LOG_ERRORS = 1,    // Only errors
   LOG_SIGNALS = 2,   // Only trade signals
   LOG_VERBOSE = 3    // Full verbose logging
};

enum ENUM_REPORT_FREQUENCY
{
   REPORT_DAILY = 0,    // Daily reports
   REPORT_WEEKLY = 1,   // Weekly reports
   REPORT_MONTHLY = 2,  // Monthly reports
   REPORT_ALL = 3       // All reports
};

// Input Parameters
input string   GeneralSettings = "===== General Settings ====="; // General Settings
input int      MagicNumber     = 12345;                         // Magic Number
input string account_title = "Road To Eldorado UM";
input ENUM_LOG_LEVEL LogLevel = LOG_VERBOSE;                    // Logging Level
input bool     EnableLogging   = true;                          // Enable Logging

// Telegram Settings
input string   TelegramSettings = "===== Telegram Settings ====="; // Telegram Settings
input bool     UseTelegram     = true;                          // Enable Telegram Notifications
input string   TelegramBotToken = "";                           // Telegram Bot Token
input string   TelegramChatID  = "41892068";                   // Telegram Chat ID
input string   BotName         = "Trading Logger";             // Bot Name


// Report Settings
input string   ReportSettings = "===== Report Settings ====="; // Report Settings
input int      ReportInterval = 30;                            // Report Interval (minutes)

// Global Variables
CTrade trade;
CSymbolInfo symbolInfo;
string accountCurrency = "$"; // Default currency

// Comprehensive Trade Record Structure (Pandas-like)
struct TradeRecord
{
   datetime openTime;
   datetime closeTime;
   string symbol;
   ENUM_POSITION_TYPE type;
   double volume;
   double openPrice;
   double closePrice;
   double profit;
   double balanceBefore;
   double balanceAfter;
   double equityBefore;
   double equityAfter;
   int dayOfYear;
   int weekOfYear;
   int monthOfYear;
   int year;
   string dateStr;
   string weekStr;
   string monthStr;
};

// Statistics Structure
struct TradingStats
{
   // Bot start tracking
   datetime botStartTime;
   double botStartEquity;
   double botPeakEquity;
   double botMaxDD;        // Now tracks max DD percentage
   double maxCurrentDD;    // Track maximum Current DD percentage
   
   // Last report time
   datetime lastReportSent;
   
   // Trade history
   TradeRecord tradeHistory[];
   int tradeHistoryCount;
   datetime lastHistoryUpdate;
};

TradingStats stats;



//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize trade object
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   // Initialize symbol info
   if(!symbolInfo.Name(_Symbol))
   {
      Print("Failed to initialize symbol info");
      return INIT_FAILED;
   }
   
   // Initialize statistics
   InitializeStats();
   
   // Initialize account currency
   InitializeAccountCurrency();
   
   // Initialize Telegram
   if(UseTelegram)
   {
      if(!InitializeTelegram())
      {
         Print("Warning: Telegram initialization failed, continuing without notifications");
      }
   }
   
   // Send startup message
   string startupMessage = "🚀 EA Logger initialized successfully!\n";
   startupMessage += "📊 Symbol: " + _Symbol + "\n";
   startupMessage += "⏰ Time: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
   
   if(UseTelegram)
   {
      bool sent = SendTelegramMessage(startupMessage);
      if(!sent)
      {
         Print("⚠️ Telegram startup message failed - check your bot configuration");
      }
      }
   
   // Start timer for periodic reports
   EventSetTimer(60); // Timer every 60 seconds
   
   Print("Logger EA initialized successfully");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Stop timer
   EventKillTimer();
   
   string shutdownMessage = "";
   
   if(UseTelegram)
      SendTelegramMessage(shutdownMessage);
   
   Print("Logger EA deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!EnableLogging) return;
   
   // Update statistics
   UpdateStats();
   
   // Check for periodic report
   if(TimeCurrent() - stats.lastReportSent >= ReportInterval * 60)
   {
      SendPeriodicReport();
      stats.lastReportSent = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Expert timer function                                            |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(!EnableLogging) return;
   
   // Timer is now handled in OnTick for periodic reports
}



//+------------------------------------------------------------------+
//| Initialize statistics                                            |
//+------------------------------------------------------------------+
void InitializeStats()
{
   ZeroMemory(stats);
   
   // Initialize bot start tracking
   stats.botStartTime = TimeCurrent();
   stats.botStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   stats.botPeakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   stats.botMaxDD = 0;
   stats.maxCurrentDD = 0; // Initialize maxCurrentDD
   
   // Set last report time
   stats.lastReportSent = TimeCurrent();
   
   // Initialize trade history
   stats.tradeHistoryCount = 0;
   stats.lastHistoryUpdate = 0;
   
   // Build comprehensive trade history
   BuildTradeHistory();
   
   Print("Statistics initialized with comprehensive trade history");
}

//+------------------------------------------------------------------+
//| Build comprehensive trade history (Pandas-like approach)        |
//+------------------------------------------------------------------+
void BuildTradeHistory()
{
   Print("Building comprehensive trade history...");
   
   // Load all historical deals
   if(!HistorySelect(0, TimeCurrent()))
   {
      Print("Failed to load historical data");
      return;
   }
   
   // Clear existing data
   ArrayResize(stats.tradeHistory, 0);
   stats.tradeHistoryCount = 0;
   
   double runningBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double runningEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // First pass: calculate running balance by processing all deals in reverse order
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket > 0)
      {
         ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
         double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
         
         if(dealType == DEAL_TYPE_BALANCE)
         {
            // Deposit/withdrawal - subtract from running balance
            runningBalance -= dealProfit;
            runningEquity -= dealProfit;
         }
         else if(dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL)
         {
            // Trade - subtract from running balance
            runningBalance -= dealProfit;
            runningEquity -= dealProfit;
         }
      }
   }
   
   // Second pass: build trade history in chronological order
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket > 0)
      {
         ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
         
         if(dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL)
         {
            // This is a trade
            datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
            double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            double dealVolume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
            string dealSymbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
            double dealPrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
            
            // Create trade record
            ArrayResize(stats.tradeHistory, stats.tradeHistoryCount + 1);
            
            stats.tradeHistory[stats.tradeHistoryCount].openTime = dealTime;
            stats.tradeHistory[stats.tradeHistoryCount].closeTime = dealTime;
            stats.tradeHistory[stats.tradeHistoryCount].symbol = dealSymbol;
            stats.tradeHistory[stats.tradeHistoryCount].type = (dealType == DEAL_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
            stats.tradeHistory[stats.tradeHistoryCount].volume = dealVolume;
            stats.tradeHistory[stats.tradeHistoryCount].openPrice = dealPrice;
            stats.tradeHistory[stats.tradeHistoryCount].closePrice = dealPrice;
            stats.tradeHistory[stats.tradeHistoryCount].profit = dealProfit;
            stats.tradeHistory[stats.tradeHistoryCount].balanceBefore = runningBalance;
            stats.tradeHistory[stats.tradeHistoryCount].balanceAfter = runningBalance + dealProfit;
            stats.tradeHistory[stats.tradeHistoryCount].equityBefore = runningEquity;
            stats.tradeHistory[stats.tradeHistoryCount].equityAfter = runningEquity + dealProfit;
            
            // Calculate date components for grouping
            MqlDateTime timeStruct;
            TimeToStruct(dealTime, timeStruct);
            stats.tradeHistory[stats.tradeHistoryCount].dayOfYear = timeStruct.day_of_year;
            stats.tradeHistory[stats.tradeHistoryCount].weekOfYear = timeStruct.day_of_week;
            stats.tradeHistory[stats.tradeHistoryCount].monthOfYear = timeStruct.mon;
            stats.tradeHistory[stats.tradeHistoryCount].year = timeStruct.year;
            
            // Format date strings
            stats.tradeHistory[stats.tradeHistoryCount].dateStr = TimeToString(dealTime, TIME_DATE);
            stats.tradeHistory[stats.tradeHistoryCount].weekStr = GetWeekRangeString(dealTime);
            stats.tradeHistory[stats.tradeHistoryCount].monthStr = GetMonthRangeString(dealTime);
            
            // Update running totals
            runningBalance += dealProfit;
            runningEquity += dealProfit;
            
            stats.tradeHistoryCount++;
         }
         else if(dealType == DEAL_TYPE_BALANCE)
         {
            // This is a deposit/withdrawal - update running balance
            double balanceChange = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            runningBalance += balanceChange;
            runningEquity += balanceChange;
         }
      }
   }
   
   Print("Trade history built successfully. Total trades: ", stats.tradeHistoryCount);
}

//+------------------------------------------------------------------+
//| Get week range string (e.g., "01.08.2025-07.08.2025")          |
//+------------------------------------------------------------------+
string GetWeekRangeString(datetime time)
{
   MqlDateTime timeStruct;
   TimeToStruct(time, timeStruct);
   
   // Calculate days to subtract to get to Monday
   int daysToSubtract = (timeStruct.day_of_week == 0) ? 6 : timeStruct.day_of_week - 1;
   datetime weekStart = time - (daysToSubtract * 24 * 3600);
   datetime weekEnd = weekStart + (6 * 24 * 3600);
   
   return TimeToString(weekStart, TIME_DATE) + "-" + TimeToString(weekEnd, TIME_DATE);
}

//+------------------------------------------------------------------+
//| Get month range string (e.g., "01.08.2025-31.08.2025")         |
//+------------------------------------------------------------------+
string GetMonthRangeString(datetime time)
{
   MqlDateTime timeStruct;
   TimeToStruct(time, timeStruct);
   
   // Get first day of month
   timeStruct.day = 1;
   datetime monthStart = StructToTime(timeStruct);
   
   // Get last day of month
   timeStruct.mon++;
   timeStruct.day = 1;
   datetime nextMonthStart = StructToTime(timeStruct);
   datetime monthEnd = nextMonthStart - 1;
   
   return TimeToString(monthStart, TIME_DATE) + "-" + TimeToString(monthEnd, TIME_DATE);
}

//+------------------------------------------------------------------+
//| Generate daily performance table                                 |
//+------------------------------------------------------------------+
string GenerateDailyTable()
{
   string table = "📅 <b>DAILY PERFORMANCE</b> 📅\n";
   table += "📊 Date | Trades | Profit " + GetCurrencySymbol() + "\n";
   
   // Group trades by date
   string dates[];
   double dailyProfits[];
   int dailyTrades[];
   int dateCount = 0;
   
   for(int i = 0; i < stats.tradeHistoryCount; i++)
   {
      string currentDate = stats.tradeHistory[i].dateStr;
      bool found = false;
      
      // Find if this date already exists
      for(int j = 0; j < dateCount; j++)
      {
         if(dates[j] == currentDate)
         {
            dailyProfits[j] += stats.tradeHistory[i].profit;
            dailyTrades[j]++;
            found = true;
            break;
         }
      }
      
      // Add new date if not found
      if(!found)
      {
         ArrayResize(dates, dateCount + 1);
         ArrayResize(dailyProfits, dateCount + 1);
         ArrayResize(dailyTrades, dateCount + 1);
         
         dates[dateCount] = currentDate;
         dailyProfits[dateCount] = stats.tradeHistory[i].profit;
         dailyTrades[dateCount] = 1;
         dateCount++;
      }
   }
   
   // Add table rows (show last 10 days)
   int startIndex = MathMax(0, dateCount - 10);
   for(int i = startIndex; i < dateCount; i++)
   {
      string profitStr = (dailyProfits[i] >= 0) ? "✅ +" + DoubleToString(dailyProfits[i], 2) : "❌ " + DoubleToString(dailyProfits[i], 2);
      table += dates[i] + " | " + IntegerToString(dailyTrades[i]) + " | " + GetCurrencySymbol() + profitStr + "\n";
   }
   
   if(dateCount == 0)
      table += "📭 No trading data available\n";
   
   table += "\n";
   return table;
}

//+------------------------------------------------------------------+
//| Generate weekly performance table                                |
//+------------------------------------------------------------------+
string GenerateWeeklyTable()
{
   string table = "📆 <b>WEEKLY PERFORMANCE</b> 📆\n";
   table += "📊 Date | Trades | Profit " + GetCurrencySymbol() + "\n";
   
   // Group trades by week
   string weeks[];
   double weeklyProfits[];
   int weeklyTrades[];
   int weekCount = 0;
   
   for(int i = 0; i < stats.tradeHistoryCount; i++)
   {
      string currentWeek = stats.tradeHistory[i].weekStr;
      bool found = false;
      
      // Find if this week already exists
      for(int j = 0; j < weekCount; j++)
      {
         if(weeks[j] == currentWeek)
         {
            weeklyProfits[j] += stats.tradeHistory[i].profit;
            weeklyTrades[j]++;
            found = true;
            break;
         }
      }
      
      // Add new week if not found
      if(!found)
      {
         ArrayResize(weeks, weekCount + 1);
         ArrayResize(weeklyProfits, weekCount + 1);
         ArrayResize(weeklyTrades, weekCount + 1);
         
         weeks[weekCount] = currentWeek;
         weeklyProfits[weekCount] = stats.tradeHistory[i].profit;
         weeklyTrades[weekCount] = 1;
         weekCount++;
      }
   }
   
   // Add table rows (show last 8 weeks)
   int startIndex = MathMax(0, weekCount - 8);
   for(int i = startIndex; i < weekCount; i++)
   {
      string profitStr = (weeklyProfits[i] >= 0) ? "✅ +" + DoubleToString(weeklyProfits[i], 2) : "❌ " + DoubleToString(weeklyProfits[i], 2);
      table += weeks[i] + " | " + IntegerToString(weeklyTrades[i]) + " | " + GetCurrencySymbol() + profitStr + "\n";
   }
   
   if(weekCount == 0)
      table += "📭 No trading data available\n";
   
   table += "\n";
   return table;
}

//+------------------------------------------------------------------+
//| Generate monthly performance table                               |
//+------------------------------------------------------------------+
string GenerateMonthlyTable()
{
   string table = "📊 <b>MONTHLY PERFORMANCE</b> 📊\n";
   table += "📈 Date | Trades | Profit " + GetCurrencySymbol() + "\n";
   
   // Group trades by month
   string months[];
   double monthlyProfits[];
   int monthlyTrades[];
   int monthCount = 0;
   
   for(int i = 0; i < stats.tradeHistoryCount; i++)
   {
      string currentMonth = stats.tradeHistory[i].monthStr;
      bool found = false;
      
      // Find if this month already exists
      for(int j = 0; j < monthCount; j++)
      {
         if(months[j] == currentMonth)
         {
            monthlyProfits[j] += stats.tradeHistory[i].profit;
            monthlyTrades[j]++;
            found = true;
            break;
         }
      }
      
      // Add new month if not found
      if(!found)
      {
         ArrayResize(months, monthCount + 1);
         ArrayResize(monthlyProfits, monthCount + 1);
         ArrayResize(monthlyTrades, monthCount + 1);
         
         months[monthCount] = currentMonth;
         monthlyProfits[monthCount] = stats.tradeHistory[i].profit;
         monthlyTrades[monthCount] = 1;
         monthCount++;
      }
   }
   
   // Add table rows (show last 6 months)
   int startIndex = MathMax(0, monthCount - 6);
   for(int i = startIndex; i < monthCount; i++)
   {
      string profitStr = (monthlyProfits[i] >= 0) ? "✅ +" + DoubleToString(monthlyProfits[i], 2) : "❌ " + DoubleToString(monthlyProfits[i], 2);
      table += months[i] + " | " + IntegerToString(monthlyTrades[i]) + " | " + GetCurrencySymbol() + profitStr + "\n";
   }
   
   if(monthCount == 0)
      table += "📭 No trading data available\n";
   
   table += "\n";
   return table;
}

//+------------------------------------------------------------------+
//| Send periodic report with comprehensive tables                   |
//+------------------------------------------------------------------+
void SendPeriodicReport()
{
   // Update trade history if needed
   if(TimeCurrent() - stats.lastHistoryUpdate > 300) // Update every 5 minutes
   {
      BuildTradeHistory();
      stats.lastHistoryUpdate = TimeCurrent();
   }
   
   string message = "";
   
   // Add exciting header with stickers
   message += "🚀 <b>ROAD TO ELDORADO TRADING REPORT</b> 🚀\n";
   message += "⚡ <b>LIVE PERFORMANCE UPDATE</b> ⚡\n";
   message += "⏰ " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + "\n\n";
   
   // Account information table
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double credit = AccountInfoDouble(ACCOUNT_CREDIT);
   double margin = AccountInfoDouble(ACCOUNT_MARGIN);
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   
   // Calculate floating P&L
   double floatingPL = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         floatingPL += PositionGetDouble(POSITION_PROFIT);
      }
   }
   
   // Calculate current DD percentage
   double currentDDPercent = 0;
   if(balance > 0)
   {
      currentDDPercent = (floatingPL / balance) * 100;
   }
   
   // Add exciting account status
   message += "💰 <b>ACCOUNT STATUS</b> 💰\n";
   message += "🏆 Account: " + account_title + "\n";
   message += "💵 Balance: " + GetCurrencySymbol() + DoubleToString(balance, 2) + "\n";
   message += "📈 Equity: " + GetCurrencySymbol() + DoubleToString(equity, 2) + "\n";
   message += "💳 Credit: " + GetCurrencySymbol() + DoubleToString(credit, 2) + "\n";
   message += "📊 Margin: " + GetCurrencySymbol() + DoubleToString(margin, 2) + "\n";
   message += "🆓 Free Margin: " + GetCurrencySymbol() + DoubleToString(freeMargin, 2) + "\n";
   message += "📈 Margin Level: " + DoubleToString(marginLevel, 1) + "%\n";
   message += "💎 Floating P&L: " + GetCurrencySymbol() + DoubleToString(floatingPL, 2) + "\n";
   message += "📉 Current DD: " + DoubleToString(currentDDPercent, 1) + "%\n";
   message += "🔥 Max DD: " + DoubleToString(stats.maxCurrentDD, 1) + "%\n\n";
   
   // Add performance summary
   message += "🎯 <b>PERFORMANCE SUMMARY</b> 🎯\n";
   message += "📊 Total Trades: " + IntegerToString(stats.tradeHistoryCount) + "\n";
   message += "⏱️ Bot Running Since: " + TimeToString(stats.botStartTime, TIME_DATE|TIME_MINUTES) + "\n\n";
   
   // Generate comprehensive tables with excitement
   message += GenerateDailyTable();
   message += GenerateWeeklyTable();
   message += GenerateMonthlyTable();
   
   // Add motivational footer
   message += "💪 <b>KEEP TRADING, KEEP WINNING!</b> 💪\n";
   message += "🎲 <b>ROAD TO ELDORADO</b> 🎲\n";
   message += "⭐ <b>PROFIT IS OUR MISSION</b> ⭐\n";
   
   if(UseTelegram)
      SendTelegramMessage(message);
}

//+------------------------------------------------------------------+
//| Initialize account currency                                    |
//+------------------------------------------------------------------+
void InitializeAccountCurrency()
{
   string currency = AccountInfoString(ACCOUNT_CURRENCY);
   if(StringLen(currency) > 0)
   {
      accountCurrency = currency;
      Print("Account currency detected: ", accountCurrency);
   }
   else
   {
      // Fallback to common currencies based on account info
      string company = AccountInfoString(ACCOUNT_COMPANY);
      if(StringFind(company, "USD") >= 0 || StringFind(company, "US") >= 0)
         accountCurrency = "$";
      else if(StringFind(company, "EUR") >= 0)
         accountCurrency = "€";
      else if(StringFind(company, "GBP") >= 0)
         accountCurrency = "£";
      else if(StringFind(company, "JPY") >= 0)
         accountCurrency = "¥";
      else
         accountCurrency = "$"; // Default fallback
      
      Print("Account currency set to: ", accountCurrency, " (based on company: ", company, ")");
   }
}

//+------------------------------------------------------------------+
//| Get currency symbol with proper formatting                      |
//+------------------------------------------------------------------+
string GetCurrencySymbol()
{
   if(accountCurrency == "USC")
      return "¢ "; // Cent symbol with space
   else if(accountCurrency == "USD")
      return "$ ";
   else if(accountCurrency == "EUR")
      return "€ ";
   else if(accountCurrency == "GBP")
      return "£ ";
   else if(accountCurrency == "JPY")
      return "¥ ";
   else
      return accountCurrency + " ";
}

//+------------------------------------------------------------------+
//| Initialize Telegram functionality                               |
//+------------------------------------------------------------------+
bool InitializeTelegram()
{
   if(StringLen(TelegramBotToken) == 0)
   {
      Print("ERROR: Telegram bot token is empty");
      Print("To set up Telegram:");
      Print("1. Create a bot with @BotFather on Telegram");
      Print("2. Get your bot token");
      Print("3. Set TelegramBotToken parameter");
      return false;
   }
   
   if(StringLen(TelegramChatID) == 0)
   {
      Print("ERROR: Telegram chat ID is empty");
      Print("To get your chat ID:");
      Print("1. Send a message to your bot");
      Print("2. Visit: https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates");
      Print("3. Find your chat_id in the response");
      Print("4. Set TelegramChatID parameter");
      Print("");
      Print("Alternative method:");
      Print("1. Send /start to your bot");
      Print("2. Visit: https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates");
      Print("3. Look for 'chat' -> 'id' in the JSON response");
      Print("");
      Print("For group chats:");
      Print("1. Add your bot to the group first");
      Print("2. Send a message in the group");
      Print("3. Check getUpdates for the group chat_id");
      return false;
   }
   
   // Send test message
   string testMessage = "";
   
   bool testResult = SendTelegramMessage(testMessage);
   
   if(testResult)
   {
      Print("✅ Telegram initialized successfully");
      return true;
   }
   else
   {
      Print("❌ Telegram test message failed");
      Print("Please check:");
      Print("1. Bot token is correct");
      Print("2. Chat ID is correct");
      Print("3. URL 'https://api.telegram.org' is allowed in MT5 settings");
      return false;
   }
}

//+------------------------------------------------------------------+
//| Send message to Telegram                                        |
//+------------------------------------------------------------------+
bool SendTelegramMessage(string message)
{
   // Debug output for troubleshooting
   if(LogLevel >= LOG_VERBOSE)
   {
      Print("=== SendTelegramMessage DEBUG ===");
      Print("UseTelegram: ", UseTelegram);
      Print("Message length: ", StringLen(message));
      Print("Message content: '", message, "'");
   }
   
   if(!UseTelegram)
   {
      Print("Telegram is disabled");
      return false;
   }
   
   if(StringLen(TelegramBotToken) == 0)
   {
      Print("ERROR: Telegram bot token is empty. Please set TelegramBotToken parameter");
      return false;
   }
   
   if(StringLen(TelegramChatID) == 0)
   {
      Print("ERROR: Telegram chat ID is empty. Please set TelegramChatID parameter");
      return false;
   }
   
   string url = "https://api.telegram.org/bot" + TelegramBotToken + "/sendMessage";
   
   // Prepare the data with proper URL encoding for emojis and HTML formatting
   string data;
   if(StringFind(message, "<") >= 0 && StringFind(message, ">") >= 0)
   {
      // Message contains HTML tags, use HTML parse mode
      data = "chat_id=" + TelegramChatID + "&parse_mode=HTML&text=" + UrlEncode(message);
   }
   else
   {
      // Plain text message, don't use parse mode
      data = "chat_id=" + TelegramChatID + "&text=" + UrlEncode(message);
   }
   
   // Debug: Print the data being sent
   if(LogLevel >= LOG_VERBOSE)
   {
      Print("DEBUG: Original message: ", message);
      Print("DEBUG: Post data: ", data);
   }
   
   char post[];
   char result[];
   string headers = "Content-Type: application/x-www-form-urlencoded; charset=UTF-8\r\n";
   
   // Convert the URL-encoded data to char array
   StringToCharArray(data, post, 0, WHOLE_ARRAY, CP_UTF8);
   
   // Send the request with UTF-8 charset
   int timeout = 5000; // 5 seconds timeout
   int res = WebRequest("POST", url, headers, timeout, post, result, headers);
   
   if(res == 200)
   {
      if(LogLevel >= LOG_VERBOSE)
         Print("Telegram message sent successfully");
      return true;
   }
   else
   {
      Print("Telegram message failed. Error code: ", res);
      Print("Response headers: ", headers);
      
      // Convert result array to string to see the error message
      string response = CharArrayToString(result);
      Print("Response body: ", response);
      
      if(res == -1)
      {
         Print("ERROR: WebRequest failed with code -1. This usually means:");
         Print("1. URL 'https://api.telegram.org' is not in the allowed URLs list");
         Print("2. Go to Tools -> Options -> Expert Advisors -> Allow WebRequest for listed URL");
         Print("3. Add 'https://api.telegram.org' to the allowed URLs");
      }
      else if(res == 400)
      {
         Print("ERROR 400: Bad Request - Check your bot token and chat ID");
         Print("Make sure:");
         Print("1. Bot token is correct (starts with numbers and ends with :ABC...)");
         Print("2. Chat ID is correct (should be a number like 123456789)");
         Print("3. You have sent at least one message to your bot");
         Print("4. The bot is not blocked in the chat");
         Print("5. For group chats, make sure the bot is added to the group");
         Print("6. For private chats, start a conversation with your bot first");
         Print("");
         Print("TROUBLESHOOTING STEPS:");
         Print("1. Test with private chat first (send /start to your bot)");
         Print("2. Get private chat ID from getUpdates");
         Print("3. Add bot to group and send a message in group");
         Print("4. Get group chat ID from getUpdates");
         Print("5. Make sure bot has permission to send messages in group");
      }
      else if(res == 403)
      {
         Print("ERROR 403: Forbidden - Bots cannot send messages to other bots");
         Print("SOLUTION:");
         Print("1. Use a PERSONAL chat ID (your own user ID), not a bot ID");
         Print("2. Send /start to your bot from your personal account");
         Print("3. Get your personal chat ID from getUpdates");
         Print("4. Or use a group chat ID where your bot is a member");
         Print("");
         Print("Current chat ID appears to be another bot. Use a user or group chat ID instead.");
      }
      
      return false;
   }
}

//+------------------------------------------------------------------+
//| Convert integer to hex string                                   |
//+------------------------------------------------------------------+
string IntToHexString(int value)
{
   string hex = "";
   string hexChars = "0123456789ABCDEF";
   
   if(value == 0)
      return "00";
   
   while(value > 0)
   {
      hex = StringSubstr(hexChars, value % 16, 1) + hex;
      value = value / 16;
   }
   
   // Ensure at least 2 digits
   if(StringLen(hex) == 1)
      hex = "0" + hex;
   
   return hex;
}

//+------------------------------------------------------------------+
//| URL encode string for Telegram API                              |
//+------------------------------------------------------------------+
string UrlEncode(string inputString)
{
   string result = "";
   uchar charArray[];
   
   // Convert the input string to a UTF-8 char array
   StringToCharArray(inputString, charArray, 0, WHOLE_ARRAY, CP_UTF8);
   
   // Process each byte in the UTF-8 encoded array
   for(int i = 0; i < ArraySize(charArray) - 1; i++) // -1 to exclude null terminator
   {
      uchar ch = charArray[i];
      
      // Keep alphanumeric characters and some safe characters
      if((ch >= 48 && ch <= 57) || // 0-9
         (ch >= 65 && ch <= 90) || // A-Z
         (ch >= 97 && ch <= 122) || // a-z
         ch == 45 || ch == 46 || ch == 95 || ch == 126) // -._~
      {
         result += CharToString(ch);
      }
      else if(ch == 32) // space
      {
         result += "+";
      }
      else
      {
         // URL encode the byte as %XX
         result += "%" + IntToHexString(ch);
      }
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Get day start time                                              |
//+------------------------------------------------------------------+
datetime GetDayStartTime()
{
   MqlDateTime timeStruct;
   TimeToStruct(TimeCurrent(), timeStruct);
   timeStruct.hour = 0;
   timeStruct.min = 0;
   timeStruct.sec = 0;
   return StructToTime(timeStruct);
}

//+------------------------------------------------------------------+
//| Get week start time (Monday 00:00)                             |
//+------------------------------------------------------------------+
datetime GetWeekStartTime()
{
   MqlDateTime timeStruct;
   TimeToStruct(TimeCurrent(), timeStruct);
   
   // Calculate days to subtract to get to Monday
   int daysToSubtract = (timeStruct.day_of_week == 0) ? 6 : timeStruct.day_of_week - 1;
   
   timeStruct.hour = 0;
   timeStruct.min = 0;
   timeStruct.sec = 0;
   
   datetime startOfWeek = StructToTime(timeStruct) - (daysToSubtract * 24 * 3600);
   return startOfWeek;
}

//+------------------------------------------------------------------+
//| Get month start time                                            |
//+------------------------------------------------------------------+
datetime GetMonthStartTime()
{
   MqlDateTime timeStruct;
   TimeToStruct(TimeCurrent(), timeStruct);
   timeStruct.day = 1;
   timeStruct.hour = 0;
   timeStruct.min = 0;
   timeStruct.sec = 0;
   return StructToTime(timeStruct);
}

//+------------------------------------------------------------------+
//| Update statistics                                               |
//+------------------------------------------------------------------+
void UpdateStats()
{
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Update bot drawdown tracking
   UpdateBotDrawdown();
}

//+------------------------------------------------------------------+
//| Update bot drawdown tracking                                   |
//+------------------------------------------------------------------+
void UpdateBotDrawdown()
{
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // Update peak equity if current equity is higher
   if(currentEquity > stats.botPeakEquity)
   {
      stats.botPeakEquity = currentEquity;
   }
   
   // Calculate current DD percentage
   double currentDDPercent = 0;
   if(currentBalance > 0)
   {
      // Calculate floating P&L
      double floatingPL = 0;
      for(int i = 0; i < PositionsTotal(); i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && PositionSelectByTicket(ticket))
         {
            floatingPL += PositionGetDouble(POSITION_PROFIT);
         }
      }
      
      currentDDPercent = (floatingPL / currentBalance) * 100;
   }
   
   // Update max Current DD if current DD is more negative (worse)
   if(currentDDPercent < stats.maxCurrentDD)
   {
      stats.maxCurrentDD = currentDDPercent;
   }
   
   // Keep the old botMaxDD for backward compatibility (absolute dollar amount)
   double currentDD = stats.botPeakEquity - currentEquity;
   if(currentDD > stats.botMaxDD)
   {
      stats.botMaxDD = currentDD;
   }
}
