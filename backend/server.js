const express = require('express');
const cors = require('cors');
const { google } = require('googleapis');

const app = express();
app.use(cors());
app.use(express.json());

const PORT = 8080;

const SPREADSHEET_ID = '17EH3JK7KT7bhxGTPeST6iebzGEdXvz6MJi34AGj7rPg';

const SALES_RANGE = 'Продажи!A:Z';
const EXPENSES_RANGE = 'Expenses!A:Z';
const PLAN_RANGE = 'app_plan!A:Z';
const INVESTMENTS_RANGE = 'Вложения!A:Z';
const DISTRIBUTION_RANGE = 'app_distribution!A:Z';

const auth = new google.auth.GoogleAuth({
  keyFile: 'key.json',
  scopes: ['https://www.googleapis.com/auth/spreadsheets'],
});

// ===== UTILS =====
function toNumber(value) {
  if (!value) return 0;
  if (typeof value === 'number') return value;

  return parseFloat(
    String(value)
      .replace(/₸/g, '')
      .replace(/\s/g, '')
      .replace(',', '.')
  ) || 0;
}

function parseDate(raw) {
  if (!raw) return null;
  const value = String(raw).trim();

  if (value.includes('-')) {
    const [y, m, d] = value.split('-').map(Number);
    return new Date(y, m - 1, d);
  }

  if (value.includes('.')) {
    const [d, m, y] = value.split('.').map(Number);
    return new Date(y, m - 1, d);
  }

  if (value.includes('/')) {
    const parts = value.split('/').map(Number);
    if (String(parts[0]).length === 4) {
      const [y, m, d] = parts;
      return new Date(y, m - 1, d);
    } else {
      const [m, d, y] = parts;
      return new Date(y, m - 1, d);
    }
  }

  return null;
}

function isWithinRange(date, from, to) {
  if (!date) return false;
  if (from && date < from) return false;
  if (to && date > to) return false;
  return true;
}

async function getSheetRows(range) {
  const client = await auth.getClient();
  const sheetsApi = google.sheets({ version: 'v4', auth: client });

  const res = await sheetsApi.spreadsheets.values.get({
    spreadsheetId: SPREADSHEET_ID,
    range,
  });

  const values = res.data.values || [];
  const headers = values[0] || [];

  return values.slice(1).map(row => {
    const obj = {};
    headers.forEach((h, i) => obj[h] = row[i] || '');
    return obj;
  });
}

// ===== SALES =====
app.get('/sales', async (req, res) => {
  const rows = await getSheetRows(SALES_RANGE);
  res.json(rows);
});

// ===== PLAN =====
app.get('/plan', async (req, res) => {
  const rows = await getSheetRows(PLAN_RANGE);
  res.json(rows);
});

// ===== INVESTMENTS =====
app.get('/investments', async (req, res) => {
  const rows = await getSheetRows(INVESTMENTS_RANGE);
  res.json(rows);
});

// ===== DISTRIBUTION =====
app.get('/distribution', async (req, res) => {
  const rows = await getSheetRows(DISTRIBUTION_RANGE);
  res.json(rows);
});

// ===== SAVE DISTRIBUTION 🔥
app.post('/distribution', async (req, res) => {
  try {
    const values = req.body.values;

    const client = await auth.getClient();
    const sheetsApi = google.sheets({ version: 'v4', auth: client });

    await sheetsApi.spreadsheets.values.update({
      spreadsheetId: SPREADSHEET_ID,
      range: 'app_distribution!A1:D10',
      valueInputOption: 'USER_ENTERED',
      requestBody: { values },
    });

    res.json({ ok: true });
  } catch (error) {
    console.error('Ошибка POST /distribution:', error);
    res.status(500).json({ error: 'Ошибка сохранения' });
  }
});

// ===== ANALYTICS =====
app.get('/analytics', async (req, res) => {
  const dateFrom = req.query.date_from ? parseDate(req.query.date_from) : null;
  const dateTo = req.query.date_to ? parseDate(req.query.date_to) : null;

  const salesRows = await getSheetRows(SALES_RANGE);
  const expenseRows = await getSheetRows(EXPENSES_RANGE);

  const filteredSales = salesRows.filter(row => {
    const d = parseDate(row['Дата']);
    if (!dateFrom && !dateTo) return true;
    return isWithinRange(d, dateFrom, dateTo);
  });

  const filteredExpenses = expenseRows.filter(row => {
    const d = parseDate(row['Date'] || row['Дата']);
    if (!dateFrom && !dateTo) return true;
    return isWithinRange(d, dateFrom, dateTo);
  });

  let revenue = 0;
  let totalProfit = 0;
  let myProfit = 0;
  let alexProfit = 0;
  let totalExpenses = 0;

  for (const row of filteredSales) {
    const rrc = toNumber(row['РРЦ']);
    const cost = toNumber(row['Себестоимость']);
    const comm = toNumber(row['Комиссия Kaspi']);

    const profit = rrc - cost - comm;

    revenue += rrc;
    totalProfit += profit;

    const comment = (row['Комментарий'] || '').toString();
    const name = (row['Наименование'] || '').toLowerCase();

    const isAriston = name.includes('ariston');
    const isPlus = comment.includes('+');

    if (isAriston || isPlus) {
      myProfit += profit / 2;
      alexProfit += profit / 2;
    } else {
      alexProfit += profit;
    }
  }

  for (const row of filteredExpenses) {
    totalExpenses += toNumber(row['Сумма']);
  }

  res.json({
    revenue,
    totalProfit,
    myNet: myProfit - totalExpenses / 2,
    alexNet: alexProfit - totalExpenses / 2,
    expenses: totalExpenses,
  });
});

// ===== START =====
app.listen(PORT, () => {
  console.log(`Server started on http://localhost:${PORT}`);
});
