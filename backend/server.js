const express = require('express');
const cors = require('cors');
const { google } = require('googleapis');
const ExcelJS = require('exceljs');
const PDFDocument = require('pdfkit');
const fs = require('fs');

const app = express();
app.use(cors());
app.use(express.json({ limit: '10mb' }));

const PORT = 8080;

const MODEL_SPREADSHEET_ID = '17EH3JK7KT7bhxGTPeST6iebzGEdXvz6MJi34AGj7rPg';
const SALES_SPREADSHEET_ID = '1D26s-VjLPvg43z-Hk38fU7Y4tPFZ9h-UfFjJzQnvtB0';

const TEEG_PRICE_SPREADSHEET_ID = '16WJB_55AWQiKOvyplY4eA1hQnJHGB4JzxF4640vMp8s';
const ARISTON_PRICE_SPREADSHEET_ID = '11cAH2QbdH-FcK5oY0m59GFsr77V3HHzZ47jxC0WOKR0';

const SALES_RANGE = 'Лист1!A:O';
const SALES_WRITE_RANGE = 'Лист1!A:O';

const EXPENSES_RANGE = 'Expenses!A:Z';
const PLAN_RANGE = 'app_plan!A:Z';
const DISTRIBUTION_RANGE = 'app_distribution!A:E';
const INVESTMENTS_RANGE = 'Вложения!A:Z';
const SIDE_INCOME_RANGE = 'ДопДоходы!A:N';
const STOCK_RANGE = 'Остатки!A:B';

const TEEG_PRICE_RANGE = 'Прайс!A:E';
const ARISTON_PRICE_RANGE = 'Лист1!A:E';

const auth = new google.auth.GoogleAuth({
  keyFile: 'key.json',
  scopes: ['https://www.googleapis.com/auth/spreadsheets'],
});

const sheets = google.sheets({
  version: 'v4',
  auth,
});

function toNumber(value) {
  if (value === null || value === undefined || value === '') return 0;
  if (typeof value === 'number') return value;

  return (
    parseFloat(
      String(value)
        .replace(/₸/g, '')
        .replace(/%/g, '')
        .replace(/\s/g, '')
        .replace(',', '.')
    ) || 0
  );
}

function money(value) {
  return `${Math.round(toNumber(value)).toLocaleString('ru-RU')} ₸`;
}

function todayRu() {
  const now = new Date();
  return `${String(now.getDate()).padStart(2, '0')}.${String(
    now.getMonth() + 1
  ).padStart(2, '0')}.${now.getFullYear()}`;
}

function parseDate(raw) {
  if (!raw) return null;
  if (raw instanceof Date) return raw;

  const value = String(raw).replace("'", '').trim();
  if (!value) return null;

  const serial = Number(value);
  if (!isNaN(serial) && serial > 30000 && serial < 60000) {
    return new Date(Date.UTC(1899, 11, 30 + serial));
  }

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
    }

    const [m, d, y] = parts;
    return new Date(y, m - 1, d);
  }

  const parsed = new Date(value);
  return isNaN(parsed.getTime()) ? null : parsed;
}

function normalizeRows(values) {
  if (!values || values.length === 0) return [];

  const headers = values[0].map((h) => String(h || '').trim());

  return values.slice(1).map((row, index) => {
    const item = { __row: row };

    headers.forEach((h, i) => {
      item[h] = row[i] ?? '';
    });

    item.__index = index + 2;
    return item;
  });
}

async function getSheetsApi() {
  const client = await auth.getClient();
  return google.sheets({ version: 'v4', auth: client });
}

async function getRows(range) {
  const sheetsApi = await getSheetsApi();

  const res = await sheetsApi.spreadsheets.values.get({
    spreadsheetId: MODEL_SPREADSHEET_ID,
    range,
  });

  return normalizeRows(res.data.values || []);
}

async function getRowsFromSpreadsheet(spreadsheetId, range) {
  const sheetsApi = await getSheetsApi();

  const res = await sheetsApi.spreadsheets.values.get({
    spreadsheetId,
    range,
  });

  return normalizeRows(res.data.values || []);
}

function getCell(row, names, indexFallback = null) {
  for (const name of names) {
    if (row[name] !== undefined && row[name] !== '') return row[name];
  }

  if (indexFallback !== null && row.__row) {
    return row.__row[indexFallback] ?? '';
  }

  return '';
}

function getRowDate(row) {
  return getCell(row, ['Дата', 'date', 'Дата_рус'], 0);
}

function getChannel(row) {
  const channel = String(getCell(row, ['Канал', 'channel'], 1)).trim();
  if (channel) return channel;

  const orderNumber = String(getCell(row, ['Номер заказа', 'orderNumber'], 3)).trim();
  const commission = toNumber(getCell(row, ['Комиссия Kaspi', 'Комиссия', 'commission'], 6));

  if (orderNumber || commission > 0) return 'Каспий';
  return 'ОПТ';
}

function rowInPeriod(rowDateRaw, from, to) {
  const rowDate = parseDate(rowDateRaw);
  if (!rowDate) return false;

  rowDate.setHours(0, 0, 0, 0);

  if (from) {
    const f = new Date(from);
    f.setHours(0, 0, 0, 0);
    if (rowDate < f) return false;
  }

  if (to) {
    const t = new Date(to);
    t.setHours(23, 59, 59, 999);
    if (rowDate > t) return false;
  }

  return true;
}

function detectBrand(name) {
  const value = String(name || '').toLowerCase();

  if (value.includes('ariston')) return 'Ariston';
  if (value.includes('thermex') || value.includes('termex')) return 'Thermex';
  if (value.includes('edison') || value.includes('edisson')) return 'Edison';
  if (value.includes('etalon')) return 'Etalon';
  if (value.includes('garanterm') || value.includes('garantem')) return 'Garanterm';

  return 'Другое';
}

function cleanProductName(value) {
  let text = String(value || '').trim();
  text = text.replace(/\s+/g, ' ');

  const brands = ['Thermex', 'Ariston', 'Etalon', 'Edison', 'Garanterm'];

  for (const brand of brands) {
    text = text.replace(new RegExp(`^${brand}\\s+${brand}\\s+`, 'i'), `${brand} `);
    text = text.replace(new RegExp(`^${brand}\\s+${brand.toUpperCase()}\\s+`, 'i'), `${brand} `);
    text = text.replace(new RegExp(`^${brand.toUpperCase()}\\s+${brand}\\s+`, 'i'), `${brand} `);
    text = text.replace(new RegExp(`^${brand.toUpperCase()}\\s+${brand.toUpperCase()}\\s+`, 'i'), `${brand} `);

    text = text.replace(
      new RegExp(`^${brand}\\s+Водонагреватель\\s+${brand}\\s+`, 'i'),
      `${brand} Водонагреватель `
    );
  }

  text = text.replace(/^Ariston\s+Водонагреватель\s+Ariston\s+/i, 'Ariston Водонагреватель ');
  text = text.replace(/^Thermex\s+THERMEX\s+/i, 'Thermex ');
  text = text.replace(/^Etalon\s+ETALON\s+/i, 'Etalon ');

  return text.trim();
}

function getCurrentModelShares(row, name, comment) {
  let stasShare = toNumber(getCell(row, ['Доля Стас', 'stasShare'], 11));
  let alexShare = toNumber(getCell(row, ['Доля Алексей', 'alexShare'], 12));

  const hasTableShares =
    getCell(row, ['Доля Стас', 'stasShare'], 11) !== '' ||
    getCell(row, ['Доля Алексей', 'alexShare'], 12) !== '';

  if (hasTableShares) {
    if (stasShare > 1) stasShare = stasShare / 100;
    if (alexShare > 1) alexShare = alexShare / 100;

    return { stasShare, alexShare };
  }

  const isAriston = String(name || '').toLowerCase().includes('ariston');
  const hasPlus = String(comment || '').includes('+');

  if (isAriston || hasPlus) {
    return { stasShare: 0.5, alexShare: 0.5 };
  }

  return { stasShare: 0, alexShare: 1 };
}

function getCapitalWorkShares(distributionRows) {
  const finalRow = distributionRows.find((row) => {
    const metric = String(getCell(row, ['metric', 'Метрика', 'Показатель'], 0))
      .trim()
      .toLowerCase();

    return metric === 'итоговая доля';
  });

  if (finalRow) {
    let stasFinalShare = toNumber(getCell(finalRow, ['stas', 'Стас'], 1));
    let alexFinalShare = toNumber(getCell(finalRow, ['alexey', 'alex', 'Алексей'], 2));

    if (stasFinalShare > 1) stasFinalShare = stasFinalShare / 100;
    if (alexFinalShare > 1) alexFinalShare = alexFinalShare / 100;

    const total = stasFinalShare + alexFinalShare;

    if (total > 0) {
      return {
        stasShare: stasFinalShare / total,
        alexShare: alexFinalShare / total,
        stasCapitalShare: 0,
        alexCapitalShare: 0,
        stasWorkShare: 0,
        alexWorkShare: 0,
      };
    }
  }

  return {
    stasShare: 0.5,
    alexShare: 0.5,
    stasCapitalShare: 0.5,
    alexCapitalShare: 0.5,
    stasWorkShare: 0.5,
    alexWorkShare: 0.5,
  };
}

function getPlanValue(planRows, keywords, fallback = 0) {
  const lowerKeywords = keywords.map((x) => String(x).toLowerCase());

  for (const row of planRows) {
    const rowValues = Object.values(row)
      .filter((v) => typeof v !== 'object')
      .map((v) => String(v || '').toLowerCase());

    const joined = rowValues.join(' ');
    const matched = lowerKeywords.every((keyword) => joined.includes(keyword));

    if (!matched) continue;

    for (const value of Object.values(row)) {
      const number = toNumber(value);
      if (number > 0) return number;
    }
  }

  return fallback;
}

function normalizePriceRows(rows, source) {
  return rows
    .map((row) => {
      const brand = String(getCell(row, ['Бренд', 'brand'], 0)).trim();
      const model = String(getCell(row, ['Модель', 'model'], 1)).trim();
      const priceType = String(getCell(row, ['ТипЦены', 'Тип цены', 'priceType'], 2)).trim();
      const price = toNumber(getCell(row, ['Цена', 'price'], 3));
      const cost = toNumber(getCell(row, ['Себестоимость', 'cost'], 4));

      const fullName = cleanProductName(`${brand} ${model}`.trim());

      return {
        brand,
        model,
        priceType,
        price,
        cost,
        source,
        fullName,
      };
    })
    .filter((item) => item.model && item.price > 0);
}

// ================= ПРАЙСЫ =================

app.get('/prices', async (req, res) => {
  try {
    const teegRows = await getRowsFromSpreadsheet(
      TEEG_PRICE_SPREADSHEET_ID,
      TEEG_PRICE_RANGE
    );

    const aristonRows = await getRowsFromSpreadsheet(
      ARISTON_PRICE_SPREADSHEET_ID,
      ARISTON_PRICE_RANGE
    );

    const prices = [
      ...normalizePriceRows(teegRows, 'TEEG'),
      ...normalizePriceRows(aristonRows, 'Ariston'),
    ];

    res.json(prices);
  } catch (error) {
    console.error('Ошибка /prices:', error);
    res.status(500).json({
      error: 'Ошибка загрузки прайсов',
      details: error.message,
    });
  }
});

// ================= ДОП ДОХОДЫ =================

app.get('/side-income', async (req, res) => {
  try {
    const response = await sheets.spreadsheets.values.get({
      spreadsheetId: MODEL_SPREADSHEET_ID,
      range: SIDE_INCOME_RANGE,
    });

    const rows = response.data.values || [];
    if (rows.length <= 1) {
      return res.json([]);
    }

    const headers = rows[0];

    const data = rows.slice(1).map((row, index) => {
      const obj = {};
      headers.forEach((header, i) => {
        obj[header] = row[i] || '';
      });

      obj.rowIndex = index + 2;
      return obj;
    });

    res.json(data);
  } catch (error) {
    console.error('Ошибка /side-income:', error);
    res.status(500).json({ error: 'Ошибка загрузки доп. доходов' });
  }
});

app.post('/add-side-income', async (req, res) => {
  try {
    const {
      date,
      type,
      description,
      income,
      expense,
      comment,
      paidBy,
    } = req.body;

    const incomeNum = Number(income) || 0;
    const expenseNum = Number(expense) || 0;

    const cleanProfit = incomeNum - expenseNum;

    const halfProfit = cleanProfit / 2;

    let refundStas = 0;
    let refundAlexey = 0;

    if (paidBy === 'Стас') {
      refundStas = expenseNum;
    } else if (paidBy === 'Алексей') {
      refundAlexey = expenseNum;
    } else if (paidBy === 'Общий') {
      refundStas = expenseNum / 2;
      refundAlexey = expenseNum / 2;
    }

    const totalStas = halfProfit + refundStas;
    const totalAlexey = halfProfit + refundAlexey;

    const values = [[
      date || todayRu(),
      type || '',
      description || '',
      incomeNum,
      expenseNum,
      cleanProfit,
      halfProfit,
      halfProfit,
      comment || '',
      paidBy || '',
      refundStas,
      refundAlexey,
      totalStas,
      totalAlexey,
    ]];

    await sheets.spreadsheets.values.append({
      spreadsheetId: MODEL_SPREADSHEET_ID,
      range: 'ДопДоходы!A:N',
      valueInputOption: 'USER_ENTERED',
      requestBody: {
        values,
      },
    });

    res.json({
      success: true,
      message: 'Доп. доход добавлен',
    });
  } catch (error) {

    console.error('Ошибка /add-side-income:', error);
    res.status(500).json({ error: 'Ошибка добавления доп. дохода' });
  }
});

app.put('/expenses/:rowIndex', async (req, res) => {
  try {
    const rowIndex = Number(req.params.rowIndex);
    const { amount, owner, type, comment } = req.body;

    if (!rowIndex || rowIndex < 2) {
      return res.status(400).json({ error: 'Неверный номер строки' });
    }

    const sheetsApi = await getSheetsApi();

    await sheetsApi.spreadsheets.values.update({
      spreadsheetId: MODEL_SPREADSHEET_ID,
      range: `Expenses!A${rowIndex}:J${rowIndex}`,
      valueInputOption: 'USER_ENTERED',
      requestBody: {
        values: [[
          todayRu(),
          type || '',
          amount || '',
          '',
          '',
          '',
          '',
          owner || '',
          type || '',
          comment || '',
        ]],
      },
    });

    res.json({ ok: true });
  } catch (error) {
    console.error('Ошибка PUT /expenses:', error);
    res.status(500).json({
      error: 'Ошибка обновления расхода',
      details: error.message,
    });
  }
});

app.delete('/expenses/:rowIndex', async (req, res) => {
  try {
    const rowIndex = Number(req.params.rowIndex);

    if (!rowIndex || rowIndex < 2) {
      return res.status(400).json({ error: 'Неверный номер строки' });
    }

    const spreadsheet = await sheets.spreadsheets.get({
      spreadsheetId: MODEL_SPREADSHEET_ID,
    });

    const sheet = spreadsheet.data.sheets.find(
      (s) => s.properties.title === 'Expenses'
    );

    if (!sheet) {
      return res.status(404).json({ error: 'Лист Expenses не найден' });
    }

    await sheets.spreadsheets.batchUpdate({
      spreadsheetId: MODEL_SPREADSHEET_ID,
      requestBody: {
        requests: [
          {
            deleteDimension: {
              range: {
                sheetId: sheet.properties.sheetId,
                dimension: 'ROWS',
                startIndex: rowIndex - 1,
                endIndex: rowIndex,
              },
            },
          },
        ],
      },
    });

    res.json({ ok: true });
  } catch (error) {
    console.error('Ошибка DELETE /expenses:', error);
    res.status(500).json({
      error: 'Ошибка удаления расхода',
      details: error.message,
    });
  }
});


app.put('/side-income/:rowIndex', async (req, res) => {
  try {
    const rowIndex = Number(req.params.rowIndex);

    if (!rowIndex || rowIndex < 2) {
      return res.status(400).json({ error: 'Неверный номер строки' });
    }

    const {
      date,
      type,
      description,
      income,
      expense,
      comment,
      paidBy,
    } = req.body;

    const incomeNum = Number(income) || 0;
    const expenseNum = Number(expense) || 0;

    const cleanProfit = incomeNum - expenseNum;

    const halfProfit = cleanProfit / 2;

    let refundStas = 0;
    let refundAlexey = 0;

    if (paidBy === 'Стас') {
      refundStas = expenseNum;
    } else if (paidBy === 'Алексей') {
      refundAlexey = expenseNum;
    } else if (paidBy === 'Общий') {
      refundStas = expenseNum / 2;
      refundAlexey = expenseNum / 2;
    }

    const totalStas = halfProfit + refundStas;
    const totalAlexey = halfProfit + refundAlexey;

    const values = [[
      date || todayRu(),
      type || '',
      description || '',
      incomeNum,
      expenseNum,
      cleanProfit,
      halfProfit,
      halfProfit,
      comment || '',
      paidBy || '',
      refundStas,
      refundAlexey,
      totalStas,
      totalAlexey,
    ]];

    await sheets.spreadsheets.values.update({
      spreadsheetId: MODEL_SPREADSHEET_ID,
      range: `ДопДоходы!A${rowIndex}:N${rowIndex}`,
      valueInputOption: 'USER_ENTERED',
      requestBody: {
        values,
      },
    });

    res.json({
      success: true,
      message: 'Доп. доход обновлен',
    });
  } catch (error) {

    console.error('Ошибка PUT /side-income:', error);
    res.status(500).json({ error: 'Ошибка обновления доп. дохода' });
  }
});

app.delete('/side-income/:rowIndex', async (req, res) => {
  try {
    const rowIndex = Number(req.params.rowIndex);

    if (!rowIndex || rowIndex < 2) {
      return res.status(400).json({ error: 'Неверный номер строки' });
    }

    const spreadsheet = await sheets.spreadsheets.get({
      spreadsheetId: MODEL_SPREADSHEET_ID,
    });

    const sheet = spreadsheet.data.sheets.find(
      (s) => s.properties.title === 'ДопДоходы'
    );

    if (!sheet) {
      return res.status(404).json({ error: 'Лист ДопДоходы не найден' });
    }

    const sheetId = sheet.properties.sheetId;

    await sheets.spreadsheets.batchUpdate({
      spreadsheetId: MODEL_SPREADSHEET_ID,
      requestBody: {
        requests: [
          {
            deleteDimension: {
              range: {
                sheetId,
                dimension: 'ROWS',
                startIndex: rowIndex - 1,
                endIndex: rowIndex,
              },
            },
          },
        ],
      },
    });

    res.json({
      success: true,
      message: 'Доп. доход удален',
    });
  } catch (error) {
    console.error('Ошибка DELETE /side-income:', error);
    res.status(500).json({ error: 'Ошибка удаления доп. дохода' });
  }
});

// ================= ПРОДАЖИ =================

app.get('/sales', async (req, res) => {
  try {
    const rows = await getRowsFromSpreadsheet(
      SALES_SPREADSHEET_ID,
      SALES_RANGE
    );

    const sales = rows.map((row) => {
      const product = cleanProductName(
        getCell(row, ['Наименование', 'Товар', 'Модель', 'Название'], 2)
      );

      return {
        ...row,
        Наименование: product,
        Товар: product,
        productName: product,
        product,
        name: product,
      };
    });

    res.json(sales);
  } catch (error) {
    console.error('Ошибка /sales:', error);
    res.status(500).json({
      error: 'Ошибка загрузки продаж',
      details: error.message,
    });
  }
});
app.post('/add-sale', async (req, res) => {
  try {
    const {
      items,
      name,
      model,
      quantity,
      cost,
      price,
      commission,
      comment,
      client,
      channel,
      orderNumber,
    } = req.body;

    const sourceItems = Array.isArray(items) && items.length > 0
      ? items
      : [
          {
            name: name || model,
            quantity,
            cost,
            price,
            commission,
            comment,
            client,
            channel,
            orderNumber,
          },
        ];

    const date = todayRu();
    const batchId = `BATCH-${Date.now()}`;
    const values = [];

    for (const item of sourceItems) {
      const productName = cleanProductName(item.name || item.model || '');
      const qty = Math.max(1, parseInt(item.quantity || 1, 10));
      const costNumber = toNumber(item.cost);
      const priceNumber = toNumber(item.price);

      const itemChannel = String(item.channel || channel || 'ОПТ').trim();
      const itemOrderNumber =
        itemChannel === 'Каспий'
          ? String(item.orderNumber || orderNumber || '').trim()
          : '';

      const itemClient = String(item.client || client || '').trim();

      const commissionNumber =
        itemChannel === 'Каспий'
          ? toNumber(item.commission || commission || 0)
          : 0;

      let safeComment = String(item.comment || comment || '').trim();
      if (safeComment === '+') safeComment = "'+";

      if (!productName) continue;
      if (!priceNumber) continue;

      for (let i = 0; i < qty; i++) {
        const profit = priceNumber - costNumber - commissionNumber;

        values.push([
          date,
          itemChannel,
          productName,
          itemOrderNumber,
          costNumber,
          priceNumber,
          commissionNumber,
          profit,
          safeComment,
          '',
          '',
          '',
          '',
          itemClient,
          batchId,
        ]);
      }
    }

    if (values.length === 0) {
      return res.status(400).json({ error: 'Нет товаров для добавления' });
    }

    const sheetsApi = await getSheetsApi();

    const current = await sheetsApi.spreadsheets.values.get({
      spreadsheetId: SALES_SPREADSHEET_ID,
      range: 'Лист1!A:A',
    });

    const usedRows = current.data.values || [];
    const nextRow = usedRows.length + 1;

    await sheetsApi.spreadsheets.values.update({
      spreadsheetId: SALES_SPREADSHEET_ID,
      range: `Лист1!A${nextRow}:O${nextRow + values.length - 1}`,
      valueInputOption: 'USER_ENTERED',
      requestBody: { values },
    });

    res.json({ ok: true, added: values.length, batchId });
  } catch (error) {
    console.error('Ошибка /add-sale:', error);
    res.status(500).json({
      error: 'Ошибка добавления продажи',
      details: error.message,
    });
  }
});

app.post('/delete-sale', async (req, res) => {
  try {
    const { rowIndex } = req.body;

    if (!rowIndex) {
      return res.status(400).json({ error: 'Нет rowIndex' });
    }

    const sheetsApi = await getSheetsApi();

    const meta = await sheetsApi.spreadsheets.get({
      spreadsheetId: SALES_SPREADSHEET_ID,
    });

    const sheet = meta.data.sheets.find((s) => s.properties.title === 'Лист1');

    if (!sheet) {
      return res.status(400).json({ error: 'Лист1 не найден' });
    }

    const sheetId = sheet.properties.sheetId;

    await sheetsApi.spreadsheets.batchUpdate({
      spreadsheetId: SALES_SPREADSHEET_ID,
      requestBody: {
        requests: [
          {
            deleteDimension: {
              range: {
                sheetId,
                dimension: 'ROWS',
                startIndex: Number(rowIndex) - 1,
                endIndex: Number(rowIndex),
              },
            },
          },
        ],
      },
    });

    res.json({ ok: true });
  } catch (error) {
    console.error('Ошибка /delete-sale:', error);
    res.status(500).json({
      error: 'Ошибка удаления продажи',
      details: error.message,
    });
  }
});

// ================= РАСХОДЫ =================

app.get('/expenses', async (req, res) => {
  try {
    const rows = await getRows(EXPENSES_RANGE);
    res.json(rows);
  } catch (error) {
    console.error('Ошибка /expenses GET:', error);
    res.status(500).json({
      error: 'Ошибка загрузки расходов',
      details: error.message,
    });
  }
});

app.post('/expenses', async (req, res) => {
  try {
    const { amount, owner, type, comment } = req.body;
    const sheetsApi = await getSheetsApi();

    await sheetsApi.spreadsheets.values.append({
      spreadsheetId: MODEL_SPREADSHEET_ID,
      range: 'Expenses!A:J',
      valueInputOption: 'USER_ENTERED',
      insertDataOption: 'INSERT_ROWS',
      requestBody: {
        values: [[
          todayRu(),
          type || '',
          amount || '',
          '',
          '',
          '',
          '',
          owner || '',
          type || '',
          comment || '',
        ]],
      },
    });

    res.json({ ok: true });
  } catch (error) {
    console.error('Ошибка /expenses POST:', error);
    res.status(500).json({
      error: 'Ошибка расхода',
      details: error.message,
    });
  }
});

// ================= ОСТАТКИ =================

app.get('/stock', async (req, res) => {
  try {
    const rows = await getRows(STOCK_RANGE);
    res.json(rows);
  } catch (error) {
    console.error('Ошибка /stock:', error);
    res.status(500).json({
      error: 'Ошибка загрузки остатков',
      details: error.message,
    });
  }
});

app.post('/add-stock', async (req, res) => {
  try {
    const { name, quantity } = req.body;

    if (!name || !quantity) {
      return res.status(400).json({
        error: 'Не указаны наименование или количество',
      });
    }

    const sheetsApi = await getSheetsApi();

    await sheetsApi.spreadsheets.values.append({
      spreadsheetId: MODEL_SPREADSHEET_ID,
      range: STOCK_RANGE,
      valueInputOption: 'USER_ENTERED',
      insertDataOption: 'INSERT_ROWS',
      requestBody: {
        values: [[cleanProductName(name), quantity]],
      },
    });

    res.json({ ok: true });
  } catch (error) {
    console.error('Ошибка /add-stock:', error);
    res.status(500).json({
      error: 'Ошибка добавления остатка',
      details: error.message,
    });
  }
});

// ================= ПЛАН =================

app.get('/plan', async (req, res) => {
  try {
    const rows = await getRows(PLAN_RANGE);
    res.json(rows);
  } catch (error) {
    console.error('Ошибка /plan:', error);
    res.status(500).json({
      error: 'Ошибка загрузки плана',
      details: error.message,
    });
  }
});

// ================= МОДЕЛЬ =================

app.get('/distribution', async (req, res) => {
  try {
    const rows = await getRows(DISTRIBUTION_RANGE);
    res.json(rows);
  } catch (error) {
    console.error('Ошибка /distribution GET:', error);
    res.status(500).json({
      error: 'Ошибка загрузки распределения',
      details: error.message,
    });
  }
});

app.post('/distribution', async (req, res) => {
  try {
    const rows = Array.isArray(req.body) ? req.body : req.body.rows;

    if (!Array.isArray(rows)) {
      return res.status(400).json({ error: 'Нет rows для сохранения модели' });
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

    await sheetsApi.spreadsheets.values.clear({
      spreadsheetId: MODEL_SPREADSHEET_ID,
      range: 'app_distribution!A:E',
    });

    await sheetsApi.spreadsheets.values.update({
      spreadsheetId: MODEL_SPREADSHEET_ID,
      range: 'app_distribution!A1',
      valueInputOption: 'USER_ENTERED',
      requestBody: { values },
    });

    res.json({ ok: true });
  } catch (error) {
    console.error('Ошибка /distribution POST:', error);
    res.status(500).json({
      error: 'Ошибка сохранения распределения',
      details: error.message,
    });
  }
});

app.get('/investments', async (req, res) => {
  try {
    const rows = await getRows(INVESTMENTS_RANGE);
    res.json(rows);
  } catch (error) {
    console.error('Ошибка /investments:', error);
    res.status(500).json({
      error: 'Ошибка загрузки вложений',
      details: error.message,
    });
  }
});

// ================= ОБЩАЯ ФУНКЦИЯ АНАЛИТИКИ =================

async function calculateAnalytics(req, topLimit = 5) {
  const dateFrom = req.query.dateFrom || req.query.date_from || req.query.datefrom;
  const dateTo = req.query.dateTo || req.query.date_to || req.query.dateto;

  const selectedModel = String(
    req.query.model || req.query.workModel || req.query.selectedModel || 'current'
  ).trim();

  const from = dateFrom ? parseDate(dateFrom) : null;
  const to = dateTo ? parseDate(dateTo) : null;

  const salesRows = await getRowsFromSpreadsheet(SALES_SPREADSHEET_ID, SALES_RANGE);
  const expenseRows = await getRows(EXPENSES_RANGE);
  const distributionRows = await getRows(DISTRIBUTION_RANGE);
  const planRows = await getRows(PLAN_RANGE);
  const sideIncomeRows = await getRows(SIDE_INCOME_RANGE);

  const capitalWorkShares = getCapitalWorkShares(distributionRows);

  let revenue = 0;
  let totalProfit = 0;
  let myProfit = 0;
  let alexProfit = 0;

  let kaspiRevenue = 0;
  let kaspiProfit = 0;
  let kaspiCount = 0;

  let optRevenue = 0;
  let optProfit = 0;
  let optCount = 0;

  let salesCount = 0;

  let sideIncomeTotal = 0;
  let sideIncomeExpense = 0;
  let sideIncomeProfit = 0;
  let sideIncomeStas = 0;
  let sideIncomeAlexey = 0;

  const topMap = {};
  const dailyMap = {};
  const brandMap = {};
  const clientMap = {};
  const sideIncomeItems = [];

  for (const row of salesRows) {
    if ((from || to) && !rowInPeriod(getRowDate(row), from, to)) continue;

    const name = cleanProductName(getCell(row, ['Наименование', 'Товар', 'name'], 2));
    const channel = getChannel(row);
    const comment = String(getCell(row, ['Комментарий', 'comment'], 8)).trim();
    const client = String(getCell(row, ['Клиент', 'client'], 13)).trim() || 'Без клиента';

    const rrc = toNumber(getCell(row, ['РРЦ', 'Выручка', 'Цена', 'price'], 5));
    const cost = toNumber(getCell(row, ['Себестоимость', 'cost'], 4));
    const commission = toNumber(getCell(row, ['Комиссия Kaspi', 'Комиссия', 'commission'], 6));

    const profitFromSheet = toNumber(getCell(row, ['Чистая прибыль', 'Прибыль', 'profit'], 7));
    const profit = profitFromSheet !== 0 ? profitFromSheet : rrc - cost - commission;

    const shares = selectedModel === 'capital_work'
      ? {
          stasShare: capitalWorkShares.stasShare,
          alexShare: capitalWorkShares.alexShare,
        }
      : getCurrentModelShares(row, name, comment);

    const rowMyProfit = profit * shares.stasShare;
    const rowAlexProfit = profit * shares.alexShare;

    revenue += rrc;
    totalProfit += profit;
    myProfit += rowMyProfit;
    alexProfit += rowAlexProfit;
    salesCount++;

    if (channel === 'Каспий') {
      kaspiRevenue += rrc;
      kaspiProfit += profit;
      kaspiCount++;
    } else {
      optRevenue += rrc;
      optProfit += profit;
      optCount++;
    }

    if (name) {
      topMap[name] = (topMap[name] || 0) + profit;
    }

    const dateKey = String(getRowDate(row)).trim();
    if (dateKey) {
      dailyMap[dateKey] = (dailyMap[dateKey] || 0) + profit;
    }

    const brand = detectBrand(name);

    if (!brandMap[brand]) {
      brandMap[brand] = {
        brand,
        revenue: 0,
        profit: 0,
        myProfit: 0,
        alexProfit: 0,
        count: 0,
      };
    }

    brandMap[brand].revenue += rrc;
    brandMap[brand].profit += profit;
    brandMap[brand].myProfit += rowMyProfit;
    brandMap[brand].alexProfit += rowAlexProfit;
    brandMap[brand].count++;

    if (!clientMap[client]) {
      clientMap[client] = {
        client,
        revenue: 0,
        profit: 0,
        myProfit: 0,
        alexProfit: 0,
        count: 0,
      };
    }

    clientMap[client].revenue += rrc;
    clientMap[client].profit += profit;
    clientMap[client].myProfit += rowMyProfit;
    clientMap[client].alexProfit += rowAlexProfit;
    clientMap[client].count++;
  }

  let expenses = 0;

  for (const row of expenseRows) {
    const rawDate = getCell(row, ['Дата', 'date', 'Дата_рус'], 0);
    if ((from || to) && !rowInPeriod(rawDate, from, to)) continue;

    expenses += toNumber(getCell(row, ['Сумма', 'amount', 'Сумма расхода'], 2));
  }

  for (const row of sideIncomeRows) {
    const rawDate = getCell(row, ['Дата', 'date'], 0);
    if ((from || to) && !rowInPeriod(rawDate, from, to)) continue;

    const type = String(getCell(row, ['Тип', 'type'], 1)).trim();
    const description = String(getCell(row, ['Описание', 'description'], 2)).trim();
    const income = toNumber(getCell(row, ['Доход', 'income'], 3));
    const expense = toNumber(getCell(row, ['Расход', 'expense'], 4));

    const profitFromSheet = toNumber(getCell(row, ['Чистая прибыль', 'profit'], 5));
    const profit = profitFromSheet !== 0 ? profitFromSheet : income - expense;

    const comment = String(getCell(row, ['Комментарий', 'comment'], 8)).trim();

    const paidBy = String(
      getCell(row, ['Оплатил расход', 'Кто оплатил', 'Оплатил', 'paidBy'], 9)
    ).trim();

    const refundStas = toNumber(
      getCell(row, ['Возврат Стас', 'Возврат Стасу', 'refundStas'], 10)
    );

    const refundAlexey = toNumber(
      getCell(row, ['Возврат Алексей', 'Возврат Алексею', 'refundAlexey'], 11)
    );

    const totalStas = toNumber(
      getCell(row, ['Итого Стас', 'totalStas'], 12)
    );

    const totalAlexey = toNumber(
      getCell(row, ['Итого Алексей', 'totalAlexey'], 13)
    );

    sideIncomeTotal += income;
    sideIncomeExpense += expense;
    sideIncomeProfit += profit;

    sideIncomeStas += totalStas || profit / 2 + refundStas;
    sideIncomeAlexey += totalAlexey || profit / 2 + refundAlexey;

    sideIncomeItems.push({
      date: rawDate,
      type,
      description,
      income,
      expense,
      profit,
      comment,
      paidBy,
      refundStas,
      refundAlexey,
      totalStas: totalStas || profit / 2 + refundStas,
      totalAlexey: totalAlexey || profit / 2 + refundAlexey,
    });
  }

  const netProfit = totalProfit - expenses;

  let myNet = 0;
  let alexNet = 0;

  if (selectedModel === 'capital_work') {
    myProfit = netProfit * capitalWorkShares.stasShare;
    alexProfit = netProfit * capitalWorkShares.alexShare;

    myNet = myProfit;
    alexNet = alexProfit;
  } else {
    myNet = myProfit - expenses / 2;
    alexNet = alexProfit - expenses / 2;
  }

  const totalNetWithSideIncome = netProfit + sideIncomeProfit;
  const myNetWithSideIncome = myNet + sideIncomeStas;
  const alexNetWithSideIncome = alexNet + sideIncomeAlexey;

  const avgCheck = salesCount > 0 ? revenue / salesCount : 0;
  const avgProfit = salesCount > 0 ? totalProfit / salesCount : 0;
  const margin = revenue > 0 ? (totalProfit / revenue) * 100 : 0;

  const topProducts = Object.entries(topMap)
    .map(([name, profit]) => ({ name, profit }))
    .sort((a, b) => b.profit - a.profit)
    .slice(0, topLimit);

  const dailyProfit = Object.entries(dailyMap)
    .map(([date, profit]) => ({ date, profit }))
    .sort((a, b) => {
      const da = parseDate(a.date);
      const db = parseDate(b.date);
      if (!da || !db) return 0;
      return da - db;
    });

  const brands = Object.values(brandMap).sort((a, b) => b.profit - a.profit);
  const clients = Object.values(clientMap).sort((a, b) => b.profit - a.profit);

  const stasPlan = getPlanValue(planRows, ['стас'], 800000);
  const alexPlan = getPlanValue(planRows, ['алексей'], 800000);
  const revenuePlan = getPlanValue(planRows, ['выруч'], 10000000);
  const profitPlan = getPlanValue(planRows, ['приб'], 800000);

  return {
    dateFrom,
    dateTo,
    selectedModel,
    model: selectedModel,

    revenue,
    totalProfit,
    netProfit,

    myProfit,
    alexProfit,
    expenses,
    myNet,
    alexNet,

    sideIncomeTotal,
    sideIncomeExpense,
    sideIncomeProfit,
    sideIncomeStas,
    sideIncomeAlexey,
    sideIncomeItems,

    totalNetWithSideIncome,
    myNetWithSideIncome,
    alexNetWithSideIncome,

    salesCount,
    avgCheck,
    avgProfit,
    margin,

    kaspiRevenue,
    kaspiProfit,
    kaspiCount,

    optRevenue,
    optProfit,
    optCount,

    topProducts,
    dailyProfit,
    brands,
    clients,

    revenuePlan,
    profitPlan,
    stasPlan,
    alexPlan,

    capitalWorkShares,
  };
}


// ================= АНАЛИТИКА =================

app.get('/analytics', async (req, res) => {
  try {
    const data = await calculateAnalytics(req, 5);
    res.json(data);
  } catch (error) {
    console.error('Ошибка /analytics:', error);

    res.status(500).json({
      error: 'Ошибка аналитики',
      details: error.message,
    });
  }
});

// ================= НАКЛАДНАЯ EXCEL =================

app.post('/invoice-excel', async (req, res) => {
  try {
    const { items, client, channel } = req.body;

    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'Нет товаров для накладной' });
    }

    const workbook = new ExcelJS.Workbook();
    const sheet = workbook.addWorksheet('Накладная');

    sheet.mergeCells('A1:F1');
    sheet.getCell('A1').value = 'TechnoOpt';
    sheet.getCell('A1').font = { bold: true, size: 20 };
    sheet.getCell('A1').alignment = { horizontal: 'center' };

    sheet.mergeCells('A2:F2');
    sheet.getCell('A2').value = 'Накладная';
    sheet.getCell('A2').font = { bold: true, size: 16 };
    sheet.getCell('A2').alignment = { horizontal: 'center' };

    sheet.addRow([]);
    sheet.addRow(['Дата', todayRu()]);
    sheet.addRow(['Клиент', client || '']);
    sheet.addRow(['Канал', channel || '']);
    sheet.addRow([]);

    const header = sheet.addRow([
      '№',
      'Товар',
      'Кол-во',
      'Себестоимость',
      'Цена',
      'Сумма',
    ]);

    header.eachCell((cell) => {
      cell.font = { bold: true };
      cell.alignment = { horizontal: 'center' };
      cell.border = {
        top: { style: 'thin' },
        left: { style: 'thin' },
        bottom: { style: 'thin' },
        right: { style: 'thin' },
      };
    });

    let total = 0;

    items.forEach((item, index) => {
      const qty = Math.max(1, parseInt(item.quantity || 1, 10));
      const price = toNumber(item.price);
      const cost = toNumber(item.cost);
      const sum = price * qty;
      total += sum;

      const row = sheet.addRow([
        index + 1,
        cleanProductName(item.name || ''),
        qty,
        cost,
        price,
        sum,
      ]);

      row.eachCell((cell) => {
        cell.border = {
          top: { style: 'thin' },
          left: { style: 'thin' },
          bottom: { style: 'thin' },
          right: { style: 'thin' },
        };
      });
    });

    sheet.addRow([]);
    sheet.addRow(['', '', '', '', 'ИТОГО', total]);

    sheet.columns = [
      { width: 6 },
      { width: 42 },
      { width: 10 },
      { width: 16 },
      { width: 16 },
      { width: 16 },
    ];

    res.setHeader(
      'Content-Type',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    );
    res.setHeader(
      'Content-Disposition',
      'attachment; filename=invoice.xlsx'
    );

    await workbook.xlsx.write(res);
    res.end();
  } catch (error) {
    console.error('Ошибка /invoice-excel:', error);
    res.status(500).json({
      error: 'Ошибка создания Excel',
      details: error.message,
    });
  }
});

// ================= НАКЛАДНАЯ PDF =================

app.post('/invoice-pdf', (req, res) => {
  try {
    const { items, client, channel } = req.body;

    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'Нет товаров для накладной' });
    }

    const doc = new PDFDocument({ margin: 40, size: 'A4' });

    const fontPath = 'C:/Windows/Fonts/arial.ttf';
    if (fs.existsSync(fontPath)) {
      doc.font(fontPath);
    }

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', 'attachment; filename=invoice.pdf');

    doc.pipe(res);

    doc.fontSize(22).text('TechnoOpt', { align: 'center' });
    doc.moveDown(0.3);
    doc.fontSize(18).text('Накладная', { align: 'center' });

    doc.moveDown();
    doc.fontSize(11).text(`Дата: ${todayRu()}`);
    doc.text(`Клиент: ${client || '—'}`);
    doc.text(`Канал: ${channel || '—'}`);

    doc.moveDown();

    let y = doc.y;

    doc.fontSize(10);
    doc.text('№', 40, y);
    doc.text('Товар', 65, y);
    doc.text('Кол-во', 315, y);
    doc.text('Цена', 370, y);
    doc.text('Сумма', 455, y);

    y += 18;
    doc.moveTo(40, y).lineTo(555, y).stroke();

    y += 10;

    let total = 0;

    items.forEach((item, index) => {
      const qty = Math.max(1, parseInt(item.quantity || 1, 10));
      const price = toNumber(item.price);
      const sum = price * qty;
      total += sum;

      if (y > 740) {
        doc.addPage();
        y = 40;
      }

      doc.text(String(index + 1), 40, y);
      doc.text(cleanProductName(item.name || ''), 65, y, { width: 240 });
      doc.text(String(qty), 315, y);
      doc.text(money(price), 370, y);
      doc.text(money(sum), 455, y);

      y += 30;
    });

    doc.moveTo(40, y).lineTo(555, y).stroke();
    y += 18;

    doc.fontSize(14).text(`ИТОГО: ${money(total)}`, 370, y, {
      align: 'right',
    });

    doc.moveDown(3);
    doc.fontSize(11).text('Поставщик: ____________________');
    doc.moveDown();
    doc.text('Получатель: ____________________');

    doc.end();
  } catch (error) {
    console.error('Ошибка /invoice-pdf:', error);
    res.status(500).json({
      error: 'Ошибка создания PDF',
      details: error.message,
    });
  }
});

// ================= PDF HELPERS =================

async function buildAnalyticsReportData(req) {
  return calculateAnalytics(req, 10);
}

function setupPdf(res, filename) {
  const doc = new PDFDocument({ margin: 40, size: 'A4' });

  const fontPath = 'C:/Windows/Fonts/arial.ttf';
  if (fs.existsSync(fontPath)) {
    doc.font(fontPath);
  }

  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename=${filename}`);

  doc.pipe(res);
  return doc;
}

function pdfHeader(doc, title, data) {
  doc.fontSize(22).text('TechnoOpt', { align: 'center' });
  doc.moveDown(0.3);
  doc.fontSize(18).text(title, { align: 'center' });
  doc.moveDown();

  doc.fontSize(11).text(`Период: ${data.dateFrom || '—'} - ${data.dateTo || '—'}`);
  doc.text(
    `Модель: ${
      data.selectedModel === 'capital_work'
        ? 'Капитал + работа'
        : 'Текущая'
    }`
  );
  doc.moveDown();
}

function checkPage(doc, y) {
  if (y > 740) {
    doc.addPage();
    return 40;
  }

  return y;
}

// ================= PDF ОТЧЁТ ПО РАСХОДАМ =================

app.get('/expenses-report/pdf', async (req, res) => {
  try {
    const dateFrom = req.query.dateFrom;
    const dateTo = req.query.dateTo;

    const from = dateFrom ? parseDate(dateFrom) : null;
    const to = dateTo ? parseDate(dateTo) : null;

    const rows = await getRows(EXPENSES_RANGE);

    const filtered = rows.filter((row) => {
      const rawDate = getCell(row, ['Дата', 'date', 'Дата_рус'], 0);
      return rowInPeriod(rawDate, from, to);
    });

    const doc = new PDFDocument({ margin: 40, size: 'A4' });

    const fontPath = 'C:/Windows/Fonts/arial.ttf';
    if (fs.existsSync(fontPath)) {
      doc.font(fontPath);
    }

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader(
      'Content-Disposition',
      'attachment; filename=expenses-report.pdf'
    );

    doc.pipe(res);

    doc.fontSize(22).text('TechnoOpt', { align: 'center' });
    doc.moveDown(0.3);
    doc.fontSize(18).text('Отчёт по расходам', { align: 'center' });

    doc.moveDown();

    doc.fontSize(11).text(`Период: ${dateFrom || '—'} - ${dateTo || '—'}`);

    doc.moveDown();

    let y = doc.y;

    doc.fontSize(10);
    doc.text('Дата', 40, y);
    doc.text('Тип', 110, y);
    doc.text('Комментарий', 200, y);
    doc.text('Сумма', 460, y);

    y += 18;
    doc.moveTo(40, y).lineTo(555, y).stroke();
    y += 10;

    let total = 0;
    let stas = 0;
    let alex = 0;
    let common = 0;

    filtered.forEach((row) => {
      const rawDate = getCell(row, ['Дата'], 0);
      const type = String(getCell(row, ['Тип', 'type'], 1)).trim();
      const amount = toNumber(getCell(row, ['Сумма'], 2));
      const comment = String(getCell(row, ['Комментарий'], 9)).trim();

      total += amount;

      if (type.includes('Стас')) stas += amount;
      else if (type.includes('Алексей')) alex += amount;
      else common += amount;

      if (y > 740) {
        doc.addPage();
        y = 40;
      }

      doc.text(String(rawDate), 40, y);
      doc.text(type, 110, y);
      doc.text(comment || '-', 200, y, { width: 240 });
      doc.text(money(amount), 460, y);

      y += 25;
    });

    doc.moveTo(40, y).lineTo(555, y).stroke();
    y += 15;

    doc.fontSize(14).text(`ИТОГО: ${money(total)}`, 400, y, {
      align: 'right',
    });

    doc.moveDown(2);

    doc.fontSize(12).text(`Стас: ${money(stas)}`);
    doc.text(`Алексей: ${money(alex)}`);
    doc.text(`Общие: ${money(common)}`);

    doc.end();
  } catch (error) {
    console.error('Ошибка /expenses-report/pdf:', error);
    res.status(500).json({
      error: 'Ошибка PDF отчёта расходов',
      details: error.message,
    });
  }
});

// ===== ОБЩИЙ ОТЧЁТ БИЗНЕСА =====

app.get('/business-report/pdf', async (req, res) => {
  try {
    const data = await buildAnalyticsReportData(req);
    const doc = setupPdf(res, 'business-report.pdf');

    pdfHeader(doc, 'Общий отчёт бизнеса', data);

    doc.fontSize(13).text('Основные показатели');
    doc.moveDown(0.5);

    doc.fontSize(11);
    doc.text(`Выручка: ${money(data.revenue)}`);
    doc.text(`Валовая прибыль: ${money(data.totalProfit)}`);
    doc.text(`Расходы: ${money(data.expenses)}`);
    doc.text(`Чистая прибыль: ${money(data.netProfit)}`);
    doc.text(`Стас: ${money(data.myNet)}`);
    doc.text(`Алексей: ${money(data.alexNet)}`);
    doc.text(`Продаж: ${data.salesCount}`);
    doc.text(`Средний чек: ${money(data.avgCheck)}`);
    doc.text(`Средняя прибыль: ${money(data.avgProfit)}`);
    doc.text(`Маржинальность: ${data.margin.toFixed(1)}%`);

    doc.moveDown();

    doc.fontSize(13).text('Доп. доходы 50/50');
    doc.moveDown(0.5);
    doc.fontSize(11);

    doc.text(`Доход: ${money(data.sideIncomeTotal || 0)}`);
    doc.text(`Расход: ${money(data.sideIncomeExpense || 0)}`);
    doc.text(`Общая чистая прибыль: ${money(data.sideIncomeProfit || 0)}`);
    doc.text(`Стас: ${money(data.sideIncomeStas || 0)}`);
    doc.text(`Алексей: ${money(data.sideIncomeAlexey || 0)}`);

    if (Array.isArray(data.sideIncomeItems) && data.sideIncomeItems.length > 0) {
      doc.moveDown(0.5);
      doc.text('Расшифровка доп. доходов:');

      data.sideIncomeItems.forEach((item, index) => {
        doc.text(
          `${index + 1}. ${item.date || ''} / ${item.type || 'Без типа'} / ${item.description || ''}`
        );

        doc.text(
          `   Доход: ${money(item.income)} / Расход: ${money(item.expense)} / Чистая: ${money(item.profit)}`
        );

        doc.text(
          `   Оплатил расход: ${item.paidBy || 'Не указано'}`
        );

        doc.text(
          `   Возврат: Стас ${money(item.refundStas || 0)} / Алексей ${money(item.refundAlexey || 0)}`
        );

        doc.text(
          `   Итого: Стас ${money(item.totalStas || 0)} / Алексей ${money(item.totalAlexey || 0)}`
        );

        if (item.comment) {
          doc.text(`   Комментарий: ${item.comment}`);
        }

        doc.moveDown(0.3);
      });
    }

    doc.moveDown();


    doc.fontSize(13).text('Итог с доп. доходами');
    doc.moveDown(0.5);

    doc.fontSize(11);
    doc.text(`Стас по бизнесу: ${money(data.myNet || 0)}`);
    doc.text(`Доп. доход Стаса: ${money(data.sideIncomeStas || 0)}`);
    doc.fontSize(12).text(`Стас итог: ${money(data.myNetWithSideIncome || data.myNet || 0)}`);

    doc.moveDown(0.4);

    doc.fontSize(11);
    doc.text(`Алексей по бизнесу: ${money(data.alexNet || 0)}`);
    doc.text(`Доп. доход Алексея: ${money(data.sideIncomeAlexey || 0)}`);
    doc.fontSize(12).text(`Алексей итог: ${money(data.alexNetWithSideIncome || data.alexNet || 0)}`);


    doc.moveDown();

    doc.fontSize(13).text('Каналы');
    doc.moveDown(0.5);
    doc.fontSize(11);
    doc.text(`Каспий: ${money(data.kaspiRevenue)} / прибыль ${money(data.kaspiProfit)} / продаж ${data.kaspiCount}`);
    doc.text(`ОПТ: ${money(data.optRevenue)} / прибыль ${money(data.optProfit)} / продаж ${data.optCount}`);

    doc.moveDown();


    doc.end();
  } catch (error) {
    console.error('Ошибка /business-report/pdf:', error);

    res.status(500).json({
      error: 'Ошибка PDF бизнес-отчёта',
      details: error.message,
    });
  }
});

// ===== ОТЧЁТ ПО КЛИЕНТАМ =====

app.get('/clients-report/pdf', async (req, res) => {
  try {
    const data = await buildAnalyticsReportData(req);
    const doc = setupPdf(res, 'clients-report.pdf');

    pdfHeader(doc, 'Отчёт по клиентам', data);

    let y = doc.y;

    doc.fontSize(10);
    doc.text('№', 40, y);
    doc.text('Клиент', 65, y);
    doc.text('Выручка', 270, y);
    doc.text('Прибыль', 370, y);
    doc.text('Продаж', 475, y);

    y += 18;
    doc.moveTo(40, y).lineTo(555, y).stroke();
    y += 10;

    data.clients.forEach((item, index) => {
      y = checkPage(doc, y);

      doc.fontSize(10);
      doc.text(String(index + 1), 40, y);
      doc.text(String(item.client || 'Без клиента'), 65, y, { width: 190 });
      doc.text(money(item.revenue), 270, y);
      doc.text(money(item.profit), 370, y);
      doc.text(String(item.count), 485, y);

      y += 28;
    });

    y += 10;
    doc.moveTo(40, y).lineTo(555, y).stroke();
    y += 18;

    doc.fontSize(12);

    doc.text('ИТОГО выручка:', 330, y, { width: 120 });
    doc.text(money(data.revenue), 455, y, { width: 90 });

    y += 18;

    doc.text('ИТОГО прибыль:', 330, y, { width: 120 });
    doc.text(money(data.totalProfit), 455, y, { width: 90 });


    doc.end();
  } catch (error) {
    console.error('Ошибка /clients-report/pdf:', error);
    res.status(500).json({
      error: 'Ошибка PDF отчёта по клиентам',
      details: error.message,
    });
  }
});

// ===== ОТЧЁТ ПО БРЕНДАМ =====

app.get('/brands-report/pdf', async (req, res) => {
  try {
    const data = await buildAnalyticsReportData(req);
    const doc = setupPdf(res, 'brands-report.pdf');

    pdfHeader(doc, 'Отчёт по брендам', data);

    let y = doc.y;

    doc.fontSize(10);
    doc.text('№', 40, y);
    doc.text('Бренд', 65, y);
    doc.text('Выручка', 170, y);
    doc.text('Прибыль', 270, y);
    doc.text('Стас', 370, y);
    doc.text('Алексей', 455, y);

    y += 18;
    doc.moveTo(40, y).lineTo(555, y).stroke();
    y += 10;

    data.brands.forEach((item, index) => {
      y = checkPage(doc, y);

      doc.fontSize(10);
      doc.text(String(index + 1), 40, y);
      doc.text(String(item.brand || 'Другое'), 65, y, { width: 95 });
      doc.text(money(item.revenue), 170, y);
      doc.text(money(item.profit), 270, y);
      doc.text(money(item.myProfit), 370, y);
      doc.text(money(item.alexProfit), 455, y);

      y += 28;
    });

    y += 10;
    doc.moveTo(40, y).lineTo(555, y).stroke();
    y += 18;

    doc.fontSize(13).text(`ИТОГО выручка: ${money(data.revenue)}`);
    doc.text(`ИТОГО прибыль: ${money(data.totalProfit)}`);

    doc.end();
  } catch (error) {
    console.error('Ошибка /brands-report/pdf:', error);
    res.status(500).json({
      error: 'Ошибка PDF отчёта по брендам',
      details: error.message,
    });
  }
});

// ================= PDF ОТЧЁТ ПО ОСТАТКАМ =================

app.get('/stock-report/pdf', async (req, res) => {
  try {
    const stockRows = await getRows(STOCK_RANGE);

    const teegRows = await getRowsFromSpreadsheet(
      TEEG_PRICE_SPREADSHEET_ID,
      TEEG_PRICE_RANGE
    );

    const aristonRows = await getRowsFromSpreadsheet(
      ARISTON_PRICE_SPREADSHEET_ID,
      ARISTON_PRICE_RANGE
    );

    const prices = [
      ...normalizePriceRows(teegRows, 'TEEG'),
      ...normalizePriceRows(aristonRows, 'Ariston'),
    ];

    function findPrice(name) {
      const n = cleanProductName(name).toLowerCase().trim();

      return prices.find((p) => {
        const model = cleanProductName(p.model || '').toLowerCase().trim();
        const fullName = cleanProductName(p.fullName || '').toLowerCase().trim();
        return model === n || fullName === n;
      }) || prices.find((p) => {
        const model = cleanProductName(p.model || '').toLowerCase().trim();
        const fullName = cleanProductName(p.fullName || '').toLowerCase().trim();
        return model.includes(n) || fullName.includes(n) || n.includes(model);
      });
    }

    const doc = new PDFDocument({ margin: 32, size: 'A4' });

    const fontPath = 'C:/Windows/Fonts/arial.ttf';
    if (fs.existsSync(fontPath)) {
      doc.font(fontPath);
    }

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader(
      'Content-Disposition',
      'attachment; filename=stock-report.pdf'
    );

    doc.pipe(res);

    doc.fontSize(21).text('TechnoOpt', { align: 'center' });
    doc.moveDown(0.2);
    doc.fontSize(16).text('Отчёт по остаткам', { align: 'center' });

    doc.moveDown();
    doc.fontSize(10).text(`Дата отчёта: ${todayRu()}`);
    doc.moveDown(0.6);

    let totalQty = 0;
    let totalCost = 0;

    let y = doc.y;

    function drawHeader() {
      doc.fontSize(9);
      doc.text('№', 32, y);
      doc.text('Наименование', 55, y);
      doc.text('Кол-во', 350, y);
      doc.text('Себ.', 405, y);
      doc.text('Итого', 485, y);

      y += 15;
      doc.moveTo(32, y).lineTo(563, y).stroke();
      y += 8;
    }

    drawHeader();

    stockRows.forEach((row, index) => {
      const name = cleanProductName(
        getCell(row, ['Наименование', 'name', 'Модель', 'model'], 0)
      );

      const qty = toNumber(
        getCell(row, ['Количество', 'quantity', 'qty'], 1)
      );

      const price = findPrice(name);
      const cost = price ? toNumber(price.cost) : 0;
      const total = qty * cost;

      totalQty += qty;
      totalCost += total;

      if (y > 742) {
        doc.addPage();
        y = 32;
        drawHeader();
      }

      const nameHeight = doc.heightOfString(name || 'Без названия', {
        width: 285,
      });

      const rowHeight = Math.max(22, nameHeight + 6);

      doc.fontSize(8.5);
      doc.text(String(index + 1), 32, y);
      doc.text(name || 'Без названия', 55, y, { width: 285 });
      doc.text(String(qty), 355, y);
      doc.text(money(cost), 405, y, { width: 70 });
      doc.text(money(total), 485, y, { width: 75 });

      y += rowHeight;
    });

    y += 6;
    doc.moveTo(32, y).lineTo(563, y).stroke();
    y += 16;

    if (y > 700) {
      doc.addPage();
      y = 32;
    }

    doc.fontSize(12);
    doc.text(`Всего позиций: ${stockRows.length}`, 32, y);
    y += 18;
    doc.text(`Всего штук: ${totalQty}`, 32, y);
    y += 18;
    doc.fontSize(14).text(`Сумма склада: ${money(totalCost)}`, 32, y);

    doc.end();
  } catch (error) {
    console.error('Ошибка /stock-report/pdf:', error);
    res.status(500).json({
      error: 'Ошибка PDF отчёта по остаткам',
      details: error.message,
    });
  }
  });

app.listen(PORT, () => {
  console.log(`Server started on http://localhost:${PORT}`);
});
