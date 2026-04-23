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

const auth = new google.auth.GoogleAuth({
  keyFile: 'key.json',
  scopes: ['https://www.googleapis.com/auth/spreadsheets'],
});

function toNumber(value) {
  if (value === null || value === undefined) return 0;
  if (typeof value === 'number') return value;

  const cleaned = String(value)
    .replace(/₸/g, '')
    .replace(/\s/g, '')
    .replace(',', '.')
    .trim();

  const num = parseFloat(cleaned);
  return isNaN(num) ? 0 : num;
}

function parseDate(raw) {
  if (!raw) return null;
  const value = String(raw).trim();

  // dd.mm.yyyy
  if (value.includes('.')) {
    const parts = value.split('.');
    if (parts.length === 3) {
      const day = parseInt(parts[0], 10) || 1;
      const month = parseInt(parts[1], 10) || 1;
      const year = parseInt(parts[2], 10) || 2000;
      return new Date(year, month - 1, day);
    }
  }

  // yyyy/mm/dd or mm/dd/yyyy
  if (value.includes('/')) {
    const parts = value.split('/');
    if (parts.length === 3) {
      if (parts[0].length === 4) {
        const year = parseInt(parts[0], 10) || 2000;
        const month = parseInt(parts[1], 10) || 1;
        const day = parseInt(parts[2], 10) || 1;
        return new Date(year, month - 1, day);
      } else {
        const month = parseInt(parts[0], 10) || 1;
        const day = parseInt(parts[1], 10) || 1;
        const year = parseInt(parts[2], 10) || 2000;
        return new Date(year, month - 1, day);
      }
    }
  }

  const d = new Date(value);
  return isNaN(d.getTime()) ? null : d;
}

function detectChannel(row) {
  const explicit = (row['Канал'] || '').toString().trim();
  if (explicit) return explicit;

  const orderNumber = (row['Номер заказа'] || '').toString().trim();
  const kaspiMarker = toNumber(row['Каспий_маркер']);
  const kaspiCommission = toNumber(row['Комиссия Kaspi']);

  if (orderNumber || kaspiMarker > 0 || kaspiCommission > 0) {
    return 'Каспий';
  }

  return 'ОПТ';
}

function normalizeRows(values) {
  if (!values || values.length === 0) return [];
  const headers = values[0];

  return values.slice(1).map((row) => {
    const item = {};
    headers.forEach((header, index) => {
      item[header] = row[index] ?? '';
    });
    return item;
  });
}

async function getSheetRows(range) {
  const client = await auth.getClient();
  const sheets = google.sheets({ version: 'v4', auth: client });

  const response = await sheets.spreadsheets.values.get({
    spreadsheetId: SPREADSHEET_ID,
    range,
  });

  return normalizeRows(response.data.values || []);
}

function isWithinRange(date, dateFrom, dateTo) {
  if (!date) return false;

  const current = new Date(date.getFullYear(), date.getMonth(), date.getDate());

  if (dateFrom) {
    const from = new Date(
      dateFrom.getFullYear(),
      dateFrom.getMonth(),
      dateFrom.getDate(),
    );
    if (current < from) return false;
  }

  if (dateTo) {
    const to = new Date(
      dateTo.getFullYear(),
      dateTo.getMonth(),
      dateTo.getDate(),
    );
    if (current > to) return false;
  }

  return true;
}

app.get('/sales', async (req, res) => {
  try {
    const rows = await getSheetRows(SALES_RANGE);
    res.json(rows);
  } catch (error) {
    console.error('Ошибка /sales:', error);
    res.status(500).json({ error: 'Ошибка загрузки продаж' });
  }
});

app.get('/expenses', async (req, res) => {
  try {
    const rows = await getSheetRows(EXPENSES_RANGE);
    res.json(rows);
  } catch (error) {
    console.error('Ошибка /expenses:', error);
    res.status(500).json({ error: 'Ошибка загрузки расходов' });
  }
});

app.get('/analytics', async (req, res) => {
  try {
    const dateFrom = req.query.date_from ? new Date(req.query.date_from) : null;
    const dateTo = req.query.date_to ? new Date(req.query.date_to) : null;

    const salesRows = await getSheetRows(SALES_RANGE);
    const expenseRows = await getSheetRows(EXPENSES_RANGE);

    const filteredSales = salesRows.filter((row) => {
      const date = parseDate(row['Дата']);
      if (!dateFrom && !dateTo) return true;
      return isWithinRange(date, dateFrom, dateTo);
    });

    const filteredExpenses = expenseRows.filter((row) => {
      const date = parseDate(row['Дата'] || row['Дата_рус']);
      if (!dateFrom && !dateTo) return true;
      return isWithinRange(date, dateFrom, dateTo);
    });

    let revenue = 0;
    let totalProfit = 0;
    let myProfit = 0;
    let alexProfit = 0;
    let totalExpenses = 0;

    let kaspiRevenue = 0;
    let kaspiProfit = 0;
    let kaspiCount = 0;

    let optRevenue = 0;
    let optProfit = 0;
    let optCount = 0;

    const productProfitMap = {};
    const dailyProfitMap = {};

    for (const row of filteredSales) {
      const rrc = toNumber(row['РРЦ']);
      const cost = toNumber(row['Себестоимость']);
      const comm = toNumber(row['Комиссия Kaspi']);
      const profit = rrc - cost - comm;
      const channel = detectChannel(row);

      revenue += rrc;
      totalProfit += profit;

      if (channel === 'Каспий') {
        kaspiRevenue += rrc;
        kaspiProfit += profit;
        kaspiCount += 1;
      } else {
        optRevenue += rrc;
        optProfit += profit;
        optCount += 1;
      }

      const name = (row['Наименование'] || 'Без названия').toString().trim();
      const comment = (row['Комментарий'] || '').toString();
      const lowerName = name.toLowerCase();

      const isAriston = lowerName.includes('ariston');
      const isPlus = comment.includes('+');

      if (isAriston || isPlus) {
        myProfit += profit / 2;
        alexProfit += profit / 2;
      } else {
        alexProfit += profit;
      }

      productProfitMap[name] = (productProfitMap[name] || 0) + profit;

      const date = parseDate(row['Дата']);
      if (date) {
        const key =
            `${date.getDate().toString().padStart(2, '0')}.${(date.getMonth() + 1).toString().padStart(2, '0')}.${date.getFullYear()}`;
        dailyProfitMap[key] = (dailyProfitMap[key] || 0) + profit;
      }
    }

    for (const row of filteredExpenses) {
      totalExpenses += toNumber(row['Сумма']);
    }

    const topProducts = Object.entries(productProfitMap)
      .map(([name, profit]) => ({ name, profit }))
      .sort((a, b) => b.profit - a.profit)
      .slice(0, 5);

    const dailyProfit = Object.entries(dailyProfitMap)
      .map(([date, profit]) => ({ date, profit }))
      .sort((a, b) => {
        const pa = a.date.split('.');
        const pb = b.date.split('.');
        const da = new Date(pa[2], pa[1] - 1, pa[0]);
        const db = new Date(pb[2], pb[1] - 1, pb[0]);
        return db - da;
      });

    res.json({
      revenue,
      totalProfit,
      myProfit,
      alexProfit,
      expenses: totalExpenses,
      myNet: myProfit - totalExpenses / 2,
      alexNet: alexProfit - totalExpenses / 2,
      salesCount: filteredSales.length,
      avgCheck: filteredSales.length ? revenue / filteredSales.length : 0,
      avgProfit: filteredSales.length ? totalProfit / filteredSales.length : 0,
      margin: revenue ? (totalProfit / revenue) * 100 : 0,
      kaspiRevenue,
      kaspiProfit,
      kaspiCount,
      optRevenue,
      optProfit,
      optCount,
      topProducts,
      dailyProfit,
    });
  } catch (error) {
    console.error('Ошибка /analytics:', error);
    res.status(500).send('Ошибка аналитики');
  }
});

app.listen(PORT, () => {
  console.log(`Server started on http://localhost:${PORT}`);
});
