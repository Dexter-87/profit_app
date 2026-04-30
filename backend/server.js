const express = require('express');
const cors = require('cors');
const { google } = require('googleapis');

const app = express();
app.use(cors());
app.use(express.json());

const PORT = 8080;

const MODEL_SPREADSHEET_ID = '17EH3JK7KT7bhxGTPeST6iebzGEdXvz6MJi34AGj7rPg';
const SALES_SPREADSHEET_ID = '1D26s-VjLPvg43z-Hk38fU7Y4tPFZ9h-UfFjIzQnvtB0';
const SALES_RANGE = 'Продажи!A:Z';
const EXPENSES_RANGE = 'Expenses!A:Z';
const PLAN_RANGE = 'app_plan!A:Z';
const INVESTMENTS_RANGE = 'Вложения!A:Z';
const DISTRIBUTION_RANGE = 'app_distribution!A:Z';

const auth = new google.auth.GoogleAuth({
  keyFile: 'key.json',
  scopes: ['https://www.googleapis.com/auth/spreadsheets'],
});

function toNumber(value) {
  if (!value) return 0;
  if (typeof value === 'number') return value;

  return (
    parseFloat(
      String(value)
        .replace(/₸/g, '')
        .replace(/\s/g, '')
        .replace(',', '.')
    ) || 0
  );
}

function todayRu() {
  const now = new Date();
  return (
    `${now.getDate().toString().padStart(2, '0')}.` +
    `${(now.getMonth() + 1).toString().padStart(2, '0')}.` +
    `${now.getFullYear()}`
  );
}

function parseDate(raw) {
  if (!raw) return null;

  const value = String(raw).trim();
  if (!value) return null;

  if (value.includes('-')) {
    const [year, month, day] = value.split('-').map(Number);
    return new Date(year, month - 1, day);
  }

  if (value.includes('.')) {
    const [day, month, year] = value.split('.').map(Number);
    return new Date(year, month - 1, day);
  }

  if (value.includes('/')) {
    const parts = value.split('/').map(Number);

    if (String(parts[0]).length === 4) {
      const [year, month, day] = parts;
      return new Date(year, month - 1, day);
    } else {
      const [month, day, year] = parts;
      return new Date(year, month - 1, day);
    }
  }

  return null;
}

function normalizeRows(values) {
  if (!values || values.length === 0) return [];

  const headers = values[0].map((h) => String(h || '').trim());

  return values.slice(1).map((row) => {
    const item = { __row: row };

    headers.forEach((h, i) => {
      item[h] = row[i] ?? '';
    });

    return item;
  });
}

async function getSheetsApi() {
  const client = await auth.getClient();
  return google.sheets({ version: 'v4', auth: client });
}

async function getSheetRows(range) {
  const sheetsApi = await getSheetsApi();

  const res = await sheetsApi.spreadsheets.values.get({
    spreadsheetId: MODEL_SPREADSHEET_ID,
    range,
  });

  return normalizeRows(res.data.values || []);
}

function detectChannel(row) {
  if (row['Канал']) return row['Канал'];

  if (row['Номер заказа'] || toNumber(row['Комиссия Kaspi']) > 0) {
    return 'Каспий';
  }

  return 'ОПТ';
}

function isWithinRange(date, from, to) {
  if (!date) return false;
  if (from && date < from) return false;
  if (to && date > to) return false;
  return true;
}

function getModelShares(distributionRows) {
  let stas = 50;
  let alexey = 50;

  for (const row of distributionRows) {
    const metric = String(row['metric'] || row['Metric'] || '').trim();

    if (metric === 'Итоговая доля') {
      stas = toNumber(row['stas']);
      alexey = toNumber(row['alexey']);
    }
  }

  if (stas === 0 && alexey === 0) {
    return { stas: 50, alexey: 50 };
  }

  return { stas, alexey };
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

app.post('/add-sale', async (req, res) => {
  try {
    const {
      name,
      model,
      quantity,
      cost,
      price,
      comment,
      client,
    } = req.body;

    const productName = String(name || model || '').trim();
    const qty = Math.max(1, parseInt(quantity || 1, 10));
    const costNumber = toNumber(cost);
    const priceNumber = toNumber(price);

    if (!productName) {
      return res.status(400).json({ error: 'Не указано наименование товара' });
    }

    if (!priceNumber) {
      return res.status(400).json({ error: 'Не указана РРЦ / цена продажи' });
    }

    const date = todayRu();
    const sheetsApi = await getSheetsApi();

    const values = [];

    for (let i = 0; i < qty; i++) {
      values.push([
        date,                 // A Дата
        'ОПТ',                // B Канал
        productName,          // C Наименование
        '',                   // D Номер заказа
        costNumber,           // E Себестоимость
        priceNumber,          // F РРЦ
        '',                   // G Комиссия Kaspi
        '',                   // H Выручка / формула в таблице, если есть
        comment || '',        // I Комментарий
      ]);
    }

    await sheetsApi.spreadsheets.values.append({
      spreadsheetId: SALES_SPREADSHEET_ID,
      range: 'Лист1!A:I',
      valueInputOption: 'USER_ENTERED',
      insertDataOption: 'INSERT_ROWS',
      requestBody: {
        values,
      },
    });

    res.json({
      ok: true,
      addedRows: qty,
      name: productName,
      cost: costNumber,
      price: priceNumber,
    });
  } catch (error) {
    console.error('Ошибка POST /add-sale:', error);
    res.status(500).json({
      error: 'Ошибка добавления продажи',
      details: error.message,
    });
  }
});

app.get('/plan', async (req, res) => {
  try {
    const rows = await getSheetRows(PLAN_RANGE);
    res.json(rows);
  } catch (error) {
    console.error('Ошибка /plan:', error);
    res.status(500).json({ error: 'Ошибка загрузки плана' });
  }
});

app.get('/investments', async (req, res) => {
  try {
    const rows = await getSheetRows(INVESTMENTS_RANGE);
    res.json(rows);
  } catch (error) {
    console.error('Ошибка /investments:', error);
    res.status(500).json({ error: 'Ошибка загрузки вложений' });
  }
});

app.get('/distribution', async (req, res) => {
  try {
    const rows = await getSheetRows(DISTRIBUTION_RANGE);
    res.json(rows);
  } catch (error) {
    console.error('Ошибка /distribution:', error);
    res.status(500).json({ error: 'Ошибка загрузки распределения' });
  }
});

app.post('/expenses', async (req, res) => {
  try {
    const { amount, owner, type, comment } = req.body;

    if (!amount) {
      return res.status(400).json({ error: 'Не указана сумма расхода' });
    }

    const sheetsApi = await getSheetsApi();

    await sheetsApi.spreadsheets.values.append({
      spreadsheetId: MODEL_SPREADSHEET_ID,
      range: 'Expenses!A:J',
      valueInputOption: 'USER_ENTERED',
      insertDataOption: 'INSERT_ROWS',
      requestBody: {
        values: [
          [
            todayRu(),
            type || '',
            amount,
            '',
            '',
            '',
            '',
            owner || '',
            type || '',
            comment || '',
          ],
        ],
      },
    });

    res.json({ ok: true });
  } catch (error) {
    console.error('Ошибка POST /expenses:', error);
    res.status(500).json({
      error: 'Ошибка сохранения расхода',
      details: error.message,
    });
  }
});

app.get('/analytics', async (req, res) => {
  try {
    const dateFrom = req.query.date_from ? parseDate(req.query.date_from) : null;
    const dateTo = req.query.date_to ? parseDate(req.query.date_to) : null;

    const salesRows = await getSheetRows(SALES_RANGE);
    const expenseRows = await getSheetRows(EXPENSES_RANGE);
    const distributionRows = await getSheetRows(DISTRIBUTION_RANGE);

    const modelShares = getModelShares(distributionRows);

    const filteredSales = salesRows.filter((row) => {
      const d = parseDate(row['Дата']);
      if (!dateFrom && !dateTo) return true;
      return isWithinRange(d, dateFrom, dateTo);
    });

    const filteredExpenses = expenseRows.filter((row) => {
      const d = parseDate(
        row['Date'] ||
          row['RealData'] ||
          row['Дата'] ||
          row['Дата_рус']
      );

      if (!dateFrom && !dateTo) return true;
      return isWithinRange(d, dateFrom, dateTo);
    });

    let revenue = 0;
    let totalProfit = 0;
    let myProfit = 0;
    let alexProfit = 0;

    let totalExpenses = 0;
    let stasExpenses = 0;
    let alexExpenses = 0;

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

      revenue += rrc;
      totalProfit += profit;

      const channel = detectChannel(row);

      if (channel === 'Каспий') {
        kaspiRevenue += rrc;
        kaspiProfit += profit;
        kaspiCount++;
      } else {
        optRevenue += rrc;
        optProfit += profit;
        optCount++;
      }

      let name = String(row['Наименование'] || '').trim();

      if (!name) {
        name = String(row['Модель'] || '').trim();
      }

      if (!name && row.__row && row.__row[2]) {
        name = row.__row[2].toString().trim();
      }

      if (!name) {
        name = 'Товар без имени';
      }

      const comment = String(row['Комментарий'] || '');
      const isAriston = name.toLowerCase().includes('ariston');
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
          `${date.getDate().toString().padStart(2, '0')}.` +
          `${(date.getMonth() + 1).toString().padStart(2, '0')}.` +
          `${date.getFullYear()}`;

        dailyProfitMap[key] = (dailyProfitMap[key] || 0) + profit;
      }
    }

    for (const row of filteredExpenses) {
      const amount = toNumber(row['Сумма']);
      const owner = String(row['Владелец'] || row.__row?.[7] || '').trim();

      totalExpenses += amount;

      if (owner === 'Стас') {
        stasExpenses += amount;
      } else if (owner === 'Алексей') {
        alexExpenses += amount;
      } else if (owner === 'Общий' || owner === 'Общий 50/50') {
        stasExpenses += amount / 2;
        alexExpenses += amount / 2;
      } else if (owner === 'Общий по модели') {
        stasExpenses += amount * (modelShares.stas / 100);
        alexExpenses += amount * (modelShares.alexey / 100);
      } else {
        stasExpenses += amount / 2;
        alexExpenses += amount / 2;
      }
    }

    const topProducts = Object.entries(productProfitMap)
      .map(([name, profit]) => ({ name, profit }))
      .sort((a, b) => b.profit - a.profit)
      .slice(0, 5);

    const dailyProfit = Object.entries(dailyProfitMap).map(([date, profit]) => ({
      date,
      profit,
    }));

    const netProfit = totalProfit - totalExpenses;

    res.json({
      revenue,
      totalProfit,
      netProfit,

      myProfit,
      alexProfit,

      expenses: totalExpenses,
      stasExpenses,
      alexExpenses,

      myNet: myProfit - stasExpenses,
      alexNet: alexProfit - alexExpenses,

      salesCount: filteredSales.length,
      avgCheck: revenue / filteredSales.length || 0,
      avgProfit: totalProfit / filteredSales.length || 0,
      margin: revenue ? (totalProfit / revenue) * 100 : 0,

      kaspiRevenue,
      kaspiProfit,
      kaspiCount,

      optRevenue,
      optProfit,
      optCount,

      modelStasShare: modelShares.stas,
      modelAlexShare: modelShares.alexey,

      topProducts,
      dailyProfit,
    });
  } catch (e) {
    console.error(e);
    res.status(500).send('Ошибка аналитики');
  }
});

app.get('/debug-sales', async (req, res) => {
  const dateFrom = req.query.date_from ? parseDate(req.query.date_from) : null;
  const dateTo = req.query.date_to ? parseDate(req.query.date_to) : null;

  const salesRows = await getSheetRows(SALES_RANGE);

  const rows = salesRows.map((row, index) => {
    const date = parseDate(row['Дата']);
    const inRange =
      !dateFrom && !dateTo ? true : isWithinRange(date, dateFrom, dateTo);

    const name = String(
      row['Наименование'] || row['Модель'] || row.__row?.[2] || ''
    );

    const rrc = toNumber(row['РРЦ']);
    const cost = toNumber(row['Себестоимость']);
    const comm = toNumber(row['Комиссия Kaspi']);
    const profit = rrc - cost - comm;

    const comment = String(row['Комментарий'] || '');
    const isAriston = name.toLowerCase().includes('ariston');
    const isPlus = comment.includes('+');

    let stas = 0;
    let alex = 0;

    if (isAriston || isPlus) {
      stas = profit / 2;
      alex = profit / 2;
    } else {
      alex = profit;
    }

    return {
      rowNumber: index + 2,
      dateRaw: row['Дата'],
      dateParsed: date ? date.toISOString().slice(0, 10) : null,
      inRange,
      name,
      rrc,
      cost,
      comm,
      profit,
      comment,
      isAriston,
      isPlus,
      stas,
      alex,
    };
  });

  res.json(rows);
});

app.post('/distribution', async (req, res) => {
  try {
    const { rows } = req.body;

    if (!Array.isArray(rows)) {
      return res.status(400).json({ error: 'rows должен быть массивом' });
    }

    const values = [
      ['metric', 'stas', 'alexey', 'total', 'model'],
      ...rows.map((r) => [
        r.metric ?? '',
        r.stas ?? '',
        r.alexey ?? '',
        r.total ?? '',
        r.model ?? '',
      ]),
    ];

    const sheetsApi = await getSheetsApi();

    await sheetsApi.spreadsheets.values.update({
      spreadsheetId: MODEL_SPREADSHEET_ID,
      range: 'app_distribution!A:E',
      valueInputOption: 'USER_ENTERED',
      requestBody: {
        values,
      },
    });

    res.json({ ok: true });
  } catch (error) {
    console.error('Ошибка POST /distribution:', error);
    res.status(500).json({
      error: 'Ошибка сохранения модели',
      details: error.message,
    });
  }
});

app.listen(PORT, () => {
  console.log('Server started on http://localhost:8080');
});
