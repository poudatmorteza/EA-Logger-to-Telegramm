# 🚀 Road To Eldorado Trading Logger

A comprehensive MQL5 Expert Advisor that provides detailed trading performance reports via Telegram.

## ✨ Features

- 📊 **Real-time Account Monitoring**: Balance, equity, margin, floating P&L
- 📈 **Historical Performance**: Daily, weekly, and monthly trade analysis
- 💬 **Telegram Integration**: Automated reports with beautiful formatting
- 🎯 **Drawdown Tracking**: Current and maximum drawdown monitoring
- �� **Periodic Reports**: Configurable reporting intervals
- 💎 **Professional UI**: Exciting emojis and engaging presentation

## 📋 Requirements

- MetaTrader 5
- Telegram Bot Token
- Telegram Chat ID
- Internet connection for Telegram API

## ⚙️ Installation

1. **Download** `logger.mq5`
2. **Place** in your MT5 `Experts` folder
3. **Compile** the EA in MetaEditor
4. **Configure** Telegram settings in inputs
5. **Attach** to any chart

## �� Configuration

### Telegram Settings
- `TelegramBotToken`: Your bot token from @BotFather
- `TelegramChatID`: Your chat ID or group ID
- `ReportInterval`: How often to send reports (minutes)

### General Settings
- `account_title`: Your account name for reports
- `LogLevel`: Logging verbosity level

```
## 📊 Sample Report
🚀 ACCOUNT XX TRADING REPORT ��
⚡ LIVE PERFORMANCE UPDATE ⚡
�� ACCOUNT STATUS 💰
🏆 Account: ACCOUNT XX
💵 Balance: ¢ 10413.04
�� Equity: ¢ 12289.35
💎 Floating P&L: ¢ -123.69
�� Current DD: -1.2%
🔥 Max DD: -2.5%
📅 DAILY PERFORMANCE 📅
2025.08.01 | 36 | ¢ ✅ +54.29
2025.08.04 | 394 | ¢ ✅ +224.90
2025.08.05 | 312 | ¢ ✅ +141.55
�� KEEP TRADING, KEEP WINNING! 💪
```

## ��️ Technical Details

- **Language**: MQL5
- **Compatible**: MetaTrader 5
- **Data Processing**: Pandas-like comprehensive trade history
- **Memory Usage**: Optimized for large trade histories
- **Update Frequency**: Configurable (default: 30 minutes)

## 📈 Performance Features

- **742+ trades** processed in real-time
- **Comprehensive balance tracking**
- **Accurate drawdown calculations**
- **Beautiful Telegram formatting**
- **Professional trading insights**

## �� Contributing

Feel free to fork and improve this EA!

## 📄 License

MIT License - feel free to use and modify

## ⭐ Support

If you find this useful, please give it a star! ⭐

---
