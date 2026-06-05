process.env.TZ = 'Asia/Almaty';

const supabase = require('./supabase');
const express = require('express');
const cors = require('cors');
const { google } = require('googleapis');
const ExcelJS = require('exceljs');
const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

const app = express();
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.get('/supabase-test', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('clients')
      .insert([{ name: 'Тестовый клиент' }])
      .select();

    if (error) throw error;

    res.json({
      ok: true,
      message: 'Supabase работает',
      data,
    });
  } catch (e) {
    res.status(500).json({
      ok: false,
      error: e.message,
    });
  }
});
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
  keyFile: process.env.RENDER
    ? '/etc/secrets/key.json'
    : 'key.json',
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

function parseDateForSupabase(value) {
  if (!value) return '';

  const s = String(value).trim();

  if (/^\d{4}-\d{2}-\d{2}$/.test(s)) {
    return s;
  }

  const match = s.match(/^(\d{2})\.(\d{2})\.(\d{4})$/);

  if (match) {
    return `${match[3]}-${match[2]}-${match[1]}`;
  }

  return s;
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
    const { data, error } = await supabase
      .from('prices')
      .select('*');

    if (error) throw error;

    res.json(data);
  } catch (error) {
    console.error('Ошибка /prices:', error);

    res.status(500).json({
      error: 'Ошибка загрузки прайсов',
      details: error.message,
    });
  }
});
app.get('/import-prices-to-supabase', async (req, res) => {
  try {
    const teegRows = await getRowsFromSpreadsheet(
      TEEG_PRICE_SPREADSHEET_ID,
      TEEG_PRICE_RANGE
    );

    const aristonRows = await getRowsFromSpreadsheet(
      ARISTON_PRICE_SPREADSHEET_ID,
      ARISTON_PRICE_RANGE
    );

    const normalizeRows = (rows, source) => {
      return rows
        .map((row) => {
          const brand = String(getCell(row, ['Бренд', 'brand'], 0)).trim();
          const model = String(getCell(row, ['Модель', 'model'], 1)).trim();
          const priceType = String(
            getCell(row, ['ТипЦены', 'Тип цены', 'priceType'], 2)
          ).trim();

          const price = toNumber(getCell(row, ['Цена', 'price'], 3));
          const cost = toNumber(getCell(row, ['Себестоимость', 'cost'], 4));

          const fullName = cleanProductName(`${brand} ${model}`.trim());

          return {
            brand,
            model,
            price_type: priceType,
            price,
            cost,
            source,
            full_name: fullName,
          };
        })
        .filter((item) => item.model && item.price > 0);
    };

    const allPrices = [
      ...normalizeRows(teegRows, 'TEEG'),
      ...normalizeRows(aristonRows, 'ARISTON'),
    ];

    await supabase.from('prices').delete().neq('id', 0);

    const { error } = await supabase
      .from('prices')
      .insert(allPrices);

    if (error) throw error;

    res.json({
      ok: true,
      inserted: allPrices.length,
    });
  } catch (error) {
    console.error('Ошибка импорта прайсов:', error);

    res.status(500).json({
      error: error.message,
    });
  }
});
// ================= ДОП ДОХОДЫ =================

// ================= ДОП ДОХОДЫ =================

app.get('/import-side-income-to-supabase', async (req, res) => {
  try {
    const rows = await getRows(SIDE_INCOME_RANGE);

    const payload = rows.map((row) => ({
      date: getCell(row, ['Дата', 'date'], 0),
      type: getCell(row, ['Тип', 'type'], 1),
      description: getCell(row, ['Описание', 'description'], 2),
      income: toNumber(getCell(row, ['Доход', 'income'], 3)),
      expense: toNumber(getCell(row, ['Расход', 'expense'], 4)),
      profit: toNumber(getCell(row, ['Чистая прибыль', 'profit'], 5)),
      half_profit: toNumber(getCell(row, ['50/50', 'halfProfit'], 6)),
      comment: getCell(row, ['Комментарий', 'comment'], 8),
      paid_by: getCell(row, ['Оплатил расход', 'paidBy'], 9),
      refund_stas: toNumber(getCell(row, ['Возврат Стас', 'refundStas'], 10)),
      refund_alexey: toNumber(getCell(row, ['Возврат Алексей', 'refundAlexey'], 11)),
      total_stas: toNumber(getCell(row, ['Итого Стас', 'totalStas'], 12)),
      total_alexey: toNumber(getCell(row, ['Итого Алексей', 'totalAlexey'], 13)),
    }));

    await supabase.from('side_income').delete().neq('id', 0);

    const { error } = await supabase.from('side_income').insert(payload);
    if (error) throw error;

    res.json({ ok: true, imported: payload.length });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.message });
  }
});

app.get('/side-income', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('side_income')
      .select('*')
      .order('id', { ascending: false });

    if (error) throw error;

    const rows = (data || []).map((row) => ({
      rowIndex: row.id,
      Дата: row.date || '',
      Тип: row.type || '',
      Описание: row.description || '',
      Доход: row.income || 0,
      Расход: row.expense || 0,
      'Чистая прибыль': row.profit || 0,
      '50/50': row.half_profit || 0,
      Комментарий: row.comment || '',
      'Оплатил расход': row.paid_by || '',
      'Возврат Стас': row.refund_stas || 0,
      'Возврат Алексей': row.refund_alexey || 0,
      'Итого Стас': row.total_stas || 0,
      'Итого Алексей': row.total_alexey || 0,
    }));

    res.json(rows);
  } catch (error) {
    console.error('Ошибка /side-income:', error);
    res.status(500).json({
      error: 'Ошибка загрузки доп. доходов',
      details: error.message,
    });
  }
});

app.post('/add-side-income', async (req, res) => {
  try {
    const { date, type, description, income, expense, comment, paidBy } = req.body;

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
      refundStas = 0;
      refundAlexey = 0;
    }

    const totalStas = halfProfit + refundStas;
    const totalAlexey = halfProfit + refundAlexey;
    const finalDate = date || todayRu();

    const values = [[
      finalDate,
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
      requestBody: { values },
    });

    const { data, error } = await supabase
      .from('side_income')
      .insert([{
        date: finalDate,
        type: type || '',
        description: description || '',
        income: incomeNum,
        expense: expenseNum,
        profit: cleanProfit,
        half_profit: halfProfit,
        comment: comment || '',
        paid_by: paidBy || '',
        refund_stas: refundStas,
        refund_alexey: refundAlexey,
        total_stas: totalStas,
        total_alexey: totalAlexey,
      }])
      .select();

    if (error) throw error;

    res.json({ success: true, ok: true, data });
  } catch (error) {
    console.error('Ошибка /add-side-income:', error);
    res.status(500).json({
      error: 'Ошибка добавления доп. дохода',
      details: error.message,
    });
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

    const sheetsApi = await getSheetsApi();

    const valuesResponse = await sheetsApi.spreadsheets.values.get({
      spreadsheetId: MODEL_SPREADSHEET_ID,
      range: 'Expenses!A:J',
    });

    const values = valuesResponse.data.values || [];
    const expenseRow = values[rowIndex - 1];

    if (!expenseRow) {
      return res.status(404).json({ error: 'Расход не найден' });
    }

    const expenseDate = parseDateForSupabase(expenseRow[0] || '');
    const expenseType = expenseRow[1] || '';
    const expenseAmount = toNumber(expenseRow[2]);
    const expenseOwner = expenseRow[7] || '';
    const expenseComment = expenseRow[9] || '';

    const { error: supabaseDeleteError } = await supabase
      .from('expenses')
      .delete()
      .eq('date', expenseDate)
      .eq('type', expenseType)
      .eq('amount', expenseAmount)
      .eq('owner', expenseOwner)
      .eq('comment', expenseComment);

    if (supabaseDeleteError) {
      console.error('Ошибка Supabase expenses delete:', supabaseDeleteError);
    }

    const spreadsheet = await sheetsApi.spreadsheets.get({
      spreadsheetId: MODEL_SPREADSHEET_ID,
    });

    const sheet = spreadsheet.data.sheets.find(
      (s) => s.properties.title === 'Expenses'
    );

    if (!sheet) {
      return res.status(404).json({ error: 'Лист Expenses не найден' });
    }

    await sheetsApi.spreadsheets.batchUpdate({
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
    const id = Number(req.params.rowIndex);

    if (!id) {
      return res.status(400).json({ error: 'Неверный id' });
    }

    const { date, type, description, income, expense, comment, paidBy } = req.body;

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
    const finalDate = date || todayRu();

    const { data, error } = await supabase
      .from('side_income')
      .update({
        date: finalDate,
        type: type || '',
        description: description || '',
        income: incomeNum,
        expense: expenseNum,
        profit: cleanProfit,
        half_profit: halfProfit,
        comment: comment || '',
        paid_by: paidBy || '',
        refund_stas: refundStas,
        refund_alexey: refundAlexey,
        total_stas: totalStas,
        total_alexey: totalAlexey,
      })
      .eq('id', id)
      .select();

    if (error) throw error;

    res.json({ success: true, ok: true, data });
  } catch (error) {
    console.error('Ошибка PUT /side-income:', error);
    res.status(500).json({
      error: 'Ошибка обновления доп. дохода',
      details: error.message,
    });
  }
});

app.delete('/side-income/:rowIndex', async (req, res) => {
  try {
    const id = Number(req.params.rowIndex);

    if (!id) {
      return res.status(400).json({ error: 'Неверный id' });
    }

    const { data: deletedRows, error } = await supabase
      .from('side_income')
      .delete()
      .eq('id', id)
      .select();

    if (error) throw error;

    const deleted = deletedRows && deletedRows.length > 0
      ? deletedRows[0]
      : null;

    if (deleted) {
      const rowsResponse = await sheets.spreadsheets.values.get({
        spreadsheetId: MODEL_SPREADSHEET_ID,
        range: SIDE_INCOME_RANGE,
      });

      const rows = rowsResponse.data.values || [];

      const targetIndex = rows.findIndex((row, index) => {
        if (index === 0) return false;

        const rowDate = String(row[0] || '').trim();
        const rowType = String(row[1] || '').trim();
        const rowDescription = String(row[2] || '').trim();
        const rowIncome = toNumber(row[3]);
        const rowExpense = toNumber(row[4]);
        const rowComment = String(row[8] || '').trim();
        const rowPaidBy = String(row[9] || '').trim();

        return (
          rowDate === String(deleted.date || '').trim() &&
          rowType === String(deleted.type || '').trim() &&
          rowDescription === String(deleted.description || '').trim() &&
          rowIncome === toNumber(deleted.income) &&
          rowExpense === toNumber(deleted.expense) &&
          rowComment === String(deleted.comment || '').trim() &&
          rowPaidBy === String(deleted.paid_by || '').trim()
        );
      });

      if (targetIndex > 0) {
        const spreadsheet = await sheets.spreadsheets.get({
          spreadsheetId: MODEL_SPREADSHEET_ID,
        });

        const sheet = spreadsheet.data.sheets.find(
          (s) => s.properties.title === 'ДопДоходы'
        );

        if (sheet) {
          await sheets.spreadsheets.batchUpdate({
            spreadsheetId: MODEL_SPREADSHEET_ID,
            requestBody: {
              requests: [
                {
                  deleteDimension: {
                    range: {
                      sheetId: sheet.properties.sheetId,
                      dimension: 'ROWS',
                      startIndex: targetIndex,
                      endIndex: targetIndex + 1,
                    },
                  },
                },
              ],
            },
          });
        }
      }
    }

    res.json({ success: true, ok: true });
  } catch (error) {
    console.error('Ошибка DELETE /side-income:', error);
    res.status(500).json({
      error: 'Ошибка удаления доп. дохода',
      details: error.message,
    });
  }
});

// ================= ПРОДАЖИ =================



app.get('/sales', async (req, res) => {
  try {
    let data = [];
    let error = null;

    let from = 0;
    const pageSize = 1000;

    while (true) {
      const { data: chunk, error: e } = await supabase
        .from('sales')
        .select('*')
        .order('id', { ascending: false })
        .range(from, from + pageSize - 1);

      if (e) {
        error = e;
        break;
      }

      if (!chunk || chunk.length === 0) break;

      data = data.concat(chunk);

      if (chunk.length < pageSize) break;

      from += pageSize;
    }

  if (!error && data && data.length > 0) {
    const sales = data.map((row) => ({
      __index: row.id,

      Дата: row.date || '',
      Канал: row.channel || '',

      Наименование: row.product || '',
      Товар: row.product || '',

      'Номер заказа': row.order_number === 'EMPTY'
          ? ''
          : row.order_number || '',

      Себестоимость: row.cost || 0,
      РРЦ: row.price || 0,

      'Комиссия Kaspi': row.commission || 0,

      'Чистая прибыль': row.profit || 0,

      Комментарий: row.comment || '',
      Клиент: row.client || '',

      batchId: row.batch_id || '',
    }));

    return res.json(sales);
  }
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

app.get('/import-sales-to-supabase', async (req, res) => {
  try {
    const rows = await getRowsFromSpreadsheet(
      SALES_SPREADSHEET_ID,
      SALES_RANGE
    );

    const supabaseRows = rows.map((row) => ({
      date: getCell(row, ['Дата', 'date'], 0),
      channel: getChannel(row),
      product: cleanProductName(
        getCell(row, ['Наименование', 'Товар', 'Модель', 'Название'], 2)
      ),
      order_number: getCell(row, ['Номер заказа', 'orderNumber'], 3),
      cost: toNumber(getCell(row, ['Себестоимость', 'cost'], 4)),
      price: toNumber(getCell(row, ['РРЦ', 'Цена', 'price'], 5)),
      commission: toNumber(getCell(row, ['Комиссия Kaspi', 'Комиссия', 'commission'], 6)),
      profit: toNumber(getCell(row, ['Чистая прибыль', 'Прибыль', 'profit'], 7)),
      comment: getCell(row, ['Комментарий', 'comment'], 8),
      client: getCell(row, ['Клиент', 'client'], 13),
      batch_id: getCell(row, ['batchId', 'BatchId', 'BATCHID', 'Накладная'], 14),
    })).filter((row) => row.product && row.date);

    const { error: clearError } = await supabase
      .from('sales')
      .delete()
      .neq('id', 0);

    if (clearError) throw clearError;

    const chunkSize = 500;
    let imported = 0;

    for (let i = 0; i < supabaseRows.length; i += chunkSize) {
      const chunk = supabaseRows.slice(i, i + chunkSize);

      const { error } = await supabase
        .from('sales')
        .insert(chunk);

      if (error) throw error;

      imported += chunk.length;
    }

    res.json({
      ok: true,
      imported,
      totalFromGoogleSheets: rows.length,
    });
  } catch (e) {
    console.error('Ошибка импорта продаж:', e);
    res.status(500).json({
      ok: false,
      error: e.message,
    });
  }
});

app.post('/import-kaspi', async (req, res) => {
  try {
    const items = Array.isArray(req.body.items) ? req.body.items : [];

    if (items.length === 0) {
      return res.status(400).json({ error: 'Нет товаров для импорта' });
    }

    const normalizeOrderNumber = (value) => {
      return String(value || '')
        .replace(/\D/g, '')
        .trim();
    };

    const preparedItems = items
      .map((item) => ({
        ...item,
        orderNumber: normalizeOrderNumber(item.orderNumber || item.order_number),
      }))
      .filter((item) => item.orderNumber);

    const orderNumbers = preparedItems.map((item) => item.orderNumber);

    const { data: existingSales, error: existingError } = await supabase
      .from('sales')
      .select('order_number')
      .in('order_number', orderNumbers);

    if (existingError) throw existingError;

    const existingOrderNumbers = new Set(
      (existingSales || []).map((sale) => normalizeOrderNumber(sale.order_number))
    );

    const duplicates = preparedItems.filter((item) =>
      existingOrderNumbers.has(item.orderNumber)
    );

    const newItems = preparedItems.filter((item) =>
      !existingOrderNumbers.has(item.orderNumber)
    );

    if (newItems.length === 0) {
      return res.json({
        added: 0,
        duplicates: duplicates.length,
        message: `Все позиции уже есть. Дублей: ${duplicates.length}`,
      });
    }

    const { data: prices, error: pricesError } = await supabase
      .from('prices')
      .select('*');

    if (pricesError) throw pricesError;

    const normalizeText = (value) => {
      return String(value || '')
        .toLowerCase()
        .replace(/ё/g, 'е')
        .replace(/[^\wа-яА-Я0-9]+/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
    };

    const findPriceItem = (productName) => {
      const productNorm = normalizeText(productName);

      return (prices || []).find((p) => {
        const brand = normalizeText(p.brand);
        const model = normalizeText(p.model);
        const fullName = normalizeText(p.full_name || p.fullName);

        const candidate = normalizeText(`${brand} ${model} ${fullName}`);

        if (model && productNorm.includes(model)) return true;
        if (fullName && productNorm.includes(fullName)) return true;
        if (candidate && productNorm.includes(candidate)) return true;

        return false;
      });
    };

    const rowsToInsert = newItems.map((item) => {
      const priceItem = findPriceItem(item.name);

      const costPrice = Number(
        priceItem?.cost ??
        priceItem?.cost_price ??
        priceItem?.costPrice ??
        item.costPrice ??
        0
      );

      const salePrice = Number(item.salePrice || 0);
      const commission = Number(item.commission || 0);

      return {
        date: item.date,
        channel: 'Каспий',
        product: item.name,
        order_number: item.orderNumber,
        cost: costPrice,
        price: salePrice,
        commission,
        profit: salePrice - costPrice - commission,
        comment: item.comment || '',
        client: 'Kaspi',
      };
    });

    const { error: insertError } = await supabase
      .from('sales')
      .insert(rowsToInsert);

    if (insertError) {
      if (
        insertError.code === '23505' ||
        insertError.message?.includes('sales_order_number_unique')
      ) {
        return res.json({
          added: 0,
          duplicates: rowsToInsert.length,
          message: `Обнаружены дубли заказов: ${rowsToInsert.length}`,
        });
      }

      throw insertError;
    }

    res.json({
      added: newItems.length,
      duplicates: duplicates.length,
      message: `Добавлено: ${newItems.length}, дублей: ${duplicates.length}`,
    });
  } catch (error) {
    console.error('Ошибка /import-kaspi:', error);
    res.status(500).json({
      error: 'Ошибка импорта Kaspi',
      details: error.message,
    });
  }
});

app.post('/add-sale', async (req, res) => {
  try {
    const {
      items,
      date,
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

    const saleDate = date || todayRu();
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
          saleDate,
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

try {
  const supabaseRows = values.map((row) => ({
    date: row[0] || '',
    channel: row[1] || '',
    product: row[2] || '',
    order_number: row[3] || '',
    cost: Number(row[4]) || 0,
    price: Number(row[5]) || 0,
    commission: Number(row[6]) || 0,
    profit: Number(row[7]) || 0,
    comment: row[8] || '',
    client: row[13] || '',
    batch_id: row[14] || '',
  }));

  const { error: supabaseError } = await supabase
    .from('sales')
    .insert(supabaseRows);

  if (supabaseError) {
    console.error('Ошибка Supabase insert:', supabaseError);
  }
} catch (e) {
  console.error('Supabase duplicate error:', e.message);
}
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
    const { rowIndex, batchId } = req.body;

    const id = Number(rowIndex);
    const cleanBatchId = String(batchId || '').trim();

    if (!id && !cleanBatchId) {
      return res.status(400).json({ error: 'Нет rowIndex или batchId' });
    }

    let deletedFromSupabase = 0;

    if (cleanBatchId && !cleanBatchId.startsWith('ROW-')) {
      const { data, error } = await supabase
        .from('sales')
        .delete()
        .eq('batch_id', cleanBatchId)
        .select();

      if (error) throw error;
      deletedFromSupabase = data?.length || 0;
    } else if (id) {
      const { data, error } = await supabase
        .from('sales')
        .delete()
        .eq('id', id)
        .select();

      if (error) throw error;
      deletedFromSupabase = data?.length || 0;
    }

    res.json({
      ok: true,
      deleted: deletedFromSupabase,
      batchId: cleanBatchId,
      rowIndex: id || '',
    });
  } catch (error) {
    console.error('Ошибка /delete-sale:', error);
    res.status(500).json({
      error: 'Ошибка удаления продажи',
      details: error.message,
    });
  }
});

    res.json({
      ok: true,
      deleted: indexesToDelete.length,
      batchId: batchId || '',
      rowIndex: rowIndex || '',
    });
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
    const { amount, owner, type, comment, channel, date } = req.body;
    const expenseChannel = channel || 'Общие';

    const sheetsApi = await getSheetsApi();

    await sheetsApi.spreadsheets.values.append({
      spreadsheetId: MODEL_SPREADSHEET_ID,
      range: 'Expenses!A:J',
      valueInputOption: 'USER_ENTERED',
      insertDataOption: 'INSERT_ROWS',
      requestBody: {
        values: [[
          date || todayRu(),
          type || '',
          amount || '',
          expenseChannel,
          '',
          '',
          '',
          owner || '',
          type || '',
          comment || '',
        ]],
      },
    });

    try {
      const { data, error: supabaseError } = await supabase
        .from('expenses')
        .insert([{
          date: parseDateForSupabase(date || todayRu()),
          title: type || '',
          amount: toNumber(amount),
          type: type || '',
          owner: owner || '',
          channel: expenseChannel,
          comment: comment || '',
        }])
        .select();

      console.log('SUPABASE EXPENSES DATA:', data);
      console.log('SUPABASE EXPENSES ERROR:', supabaseError);

      if (supabaseError) {
        console.error('Ошибка Supabase expenses insert:', supabaseError);
      }
    } catch (supabaseCatchError) {
      console.error('Supabase expenses duplicate error:', supabaseCatchError.message);
    }

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

app.delete('/stock/:rowIndex', async (req, res) => {
  try {
    const rowIndex = Number(req.params.rowIndex);

    if (!rowIndex || rowIndex < 2) {
      return res.status(400).json({
        error: 'Неверный rowIndex',
      });
    }

    const spreadsheet = await sheets.spreadsheets.get({
      spreadsheetId: MODEL_SPREADSHEET_ID,
    });

    const sheet = spreadsheet.data.sheets.find(
      (s) => s.properties.title === 'Остатки'
    );

    if (!sheet) {
      return res.status(404).json({
        error: 'Лист Остатки не найден',
      });
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

    res.json({
      ok: true,
    });
  } catch (error) {
    console.error('Ошибка DELETE /stock:', error);

    res.status(500).json({
      error: 'Ошибка удаления остатка',
      details: error.message,
    });
  }
});

// ================= ПЛАН =================

app.get('/plan', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('plan')
      .select('*')
      .order('id', { ascending: true });

    if (error) throw error;

    const rows = (data || []).map((r) => ({
      Месяц: r.month || '',
      План: r.plan_profit || 0,
      ПланКаспий: r.plan_kaspi || 0,
      ПланОПТ: r.plan_opt || 0,
    }));

    res.json(rows);
  } catch (error) {
    console.error('Ошибка /plan:', error);
    res.status(500).json({
      error: 'Ошибка загрузки плана',
      details: error.message,
    });
  }
});

app.post('/plan', async (req, res) => {
  try {
    const {
      month,
      plan_profit,
      plan_kaspi,
      plan_opt,
      План,
      ПланКаспий,
      ПланОПТ,
    } = req.body;

    const monthName = month || req.body['Месяц'] || '';

    if (!monthName) {
      return res.status(400).json({ error: 'Не указан месяц' });
    }

    const payload = {
      month: monthName,
      plan_profit: Number(plan_profit ?? План ?? 0),
      plan_kaspi: Number(plan_kaspi ?? ПланКаспий ?? 0),
      plan_opt: Number(plan_opt ?? ПланОПТ ?? 0),
    };

    const { data, error } = await supabase
      .from('plan')
      .upsert(payload, { onConflict: 'month' })
      .select();

    if (error) throw error;

    res.json({ ok: true, data });
  } catch (error) {
    console.error('Ошибка /plan POST:', error);
    res.status(500).json({
      error: 'Ошибка сохранения плана',
      details: error.message,
    });
  }
});
// ================= МОДЕЛЬ =================

app.get('/import-distribution-to-supabase', async (req, res) => {
  try {
    const rows = await getRows(DISTRIBUTION_RANGE);

    const payload = rows.map((row) => ({
      metric: row.metric || '',
      stas: toNumber(row.stas),
      alexey: toNumber(row.alexey),
      total: toNumber(row.total),
      model: row.model || '',
    }));

    await supabase
      .from('distribution')
      .delete()
      .neq('id', 0);

    const { error } = await supabase
      .from('distribution')
      .insert(payload);

    if (error) throw error;

    res.json({
      ok: true,
      imported: payload.length,
    });
  } catch (e) {
    console.error(e);

    res.status(500).json({
      error: e.message,
    });
  }
});

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

    const payload = rows.map((r) => ({
      metric: r.metric ?? '',
      stas: toNumber(r.stas),
      alexey: toNumber(r.alexey),
      total: toNumber(r.total),
      model: r.model ?? '',
    }));

    await supabase
      .from('distribution')
      .delete()
      .neq('id', 0);

    const { error: supabaseError } = await supabase
      .from('distribution')
      .insert(payload);

    if (supabaseError) throw supabaseError;

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

  const selectedModel = 'capital_work';

  const from = dateFrom ? parseDate(dateFrom) : null;
  const to = dateTo ? parseDate(dateTo) : null;

  let salesRowsRaw = [];
  let fromSales = 0;
  const pageSize = 1000;

  while (true) {
    const { data: chunk, error } = await supabase
      .from('sales')
      .select('*')
      .range(fromSales, fromSales + pageSize - 1);

    if (error) throw error;
    if (!chunk || chunk.length === 0) break;

    salesRowsRaw = salesRowsRaw.concat(chunk);

    if (chunk.length < pageSize) break;
    fromSales += pageSize;
  }

  const { data: expenseRowsRaw } = await supabase
    .from('expenses')
    .select('*');

  const { data: distributionRowsRaw } = await supabase
    .from('distribution')
    .select('*');

  const { data: planRowsRaw } = await supabase
    .from('plan')
    .select('*');

  const salesRows = (salesRowsRaw || []).map((row) => ({
    'Дата': row.date,
    'Канал': row.channel,
    'Наименование': row.product,
    'Номер заказа': row.order_number,
    'Себестоимость': row.cost,
    'РРЦ': row.price,
    'Комиссия Kaspi': row.commission,
    'Чистая прибыль': row.profit,
    'Комментарий': row.comment,
    'Клиент': row.client,
  }));

  const expenseRows = (expenseRowsRaw || []).map((row) => ({
    'Дата': row.date,
    'Сумма': row.amount,
    'Тип': row.type,
    'Канал': row.channel || 'Общие',
    'Комментарий': row.comment,
    'Владелец': row.owner,
  }));

  const distributionRows = (distributionRowsRaw || []).map((row) => ({
    metric: row.metric,
    stas: row.stas,
    alexey: row.alexey,
    total: row.total,
    model: row.model,
  }));

  const planRows = (planRowsRaw || []).map((row) => ({
    'Месяц': row.month,
    'План': row.plan_profit,
    'ПланКаспий': row.plan_kaspi,
    'ПланОПТ': row.plan_opt,
  }));

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

    const calculatedProfit = rrc - cost - commission;
    const profit = calculatedProfit;

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

  const amount = toNumber(
    getCell(row, ['Сумма', 'amount'], 2)
  );

  expenses += amount;
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

  const currentMonthName = (() => {
    const baseDate = from || new Date();

    const monthNames = [
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];

    return monthNames[baseDate.getMonth()];
  })();

  const currentPlanRow = planRows.find((row) => {
    const month = String(row['Месяц'] || row.month || '')
      .trim()
      .toLowerCase();

    return month === currentMonthName.toLowerCase();
  });

  const revenuePlan = currentPlanRow
    ? toNumber(currentPlanRow['ПланКаспий']) + toNumber(currentPlanRow['ПланОПТ'])
    : 10000000;

  const profitPlan = currentPlanRow
    ? toNumber(currentPlanRow['План'])
    : 800000;

  const stasPlan = profitPlan * capitalWorkShares.stasShare;
  const alexPlan = profitPlan * capitalWorkShares.alexShare;

  // ================= БИЗНЕС ВЫВОДЫ =================

  const insights = [];

  // Лучший бренд
  if (brands.length > 0) {
    const topBrand = brands[0];

    const share =
      totalProfit > 0
        ? (topBrand.profit / totalProfit) * 100
        : 0;

    if (share >= 20) {
      insights.push({
        type: 'success',
        icon: '🔥',
        text: `${topBrand.brand} дал ${share.toFixed(0)}% прибыли за период`,
      });
    }
  }

  // Лучший клиент
  if (clients.length > 0) {
    const topClient = clients[0];

    insights.push({
      type: 'info',
      icon: '🏆',
      text: `${topClient.client} — лучший клиент периода`,
    });
  }

  // Лучший товар
  if (topProducts.length > 0) {
    insights.push({
      type: 'success',
      icon: '📦',
      text: `${topProducts[0].name} — самый прибыльный товар`,
    });
  }

  // Маржинальность
  if (margin < 12) {
    insights.push({
      type: 'danger',
      icon: '⚠️',
      text: `Маржинальность снизилась до ${margin.toFixed(1)}%`,
    });
  } else if (margin > 20) {
    insights.push({
      type: 'success',
      icon: '💰',
      text: `Маржинальность выросла до ${margin.toFixed(1)}%`,
    });
  }

  // Расходы Каспий / ОПТ
  let kaspiExpenses = 0;
  let optExpenses = 0;
  let commonExpenses = 0;

  for (const row of expenseRows) {
    const rawDate = getCell(row, ['Дата', 'date', 'Дата_рус'], 0);

    if ((from || to) && !rowInPeriod(rawDate, from, to)) continue;

    const amount = toNumber(
      getCell(row, ['Сумма', 'amount'], 2)
    );

    const expenseChannel = String(
      getCell(row, ['Канал', 'channel'], 3)
    ).trim();

    if (expenseChannel === 'Каспий') {
      kaspiExpenses += amount;
    } else if (expenseChannel === 'ОПТ') {
      optExpenses += amount;
    } else {
      commonExpenses += amount;
    }
  }

  if (kaspiProfit > 0) {
    const kaspiExpensePercent =
      (kaspiExpenses / kaspiProfit) * 100;

    if (kaspiExpensePercent > 15) {
      insights.push({
        type: 'warning',
        icon: '📉',
        text: `Расходы Каспий составляют ${kaspiExpensePercent.toFixed(0)}% прибыли`,
      });
    }
  }

  if (optProfit > 0) {
    const optExpensePercent =
      (optExpenses / optProfit) * 100;

    if (optExpensePercent > 15) {
      insights.push({
        type: 'warning',
        icon: '📉',
        text: `Расходы ОПТ составляют ${optExpensePercent.toFixed(0)}% прибыли`,
      });
    }
  }

  // Выполнение плана
  if (profitPlan > 0) {
    const percent =
      (netProfit / profitPlan) * 100;

    if (percent >= 100) {
      insights.push({
        type: 'success',
        icon: '🚀',
        text: `План выполнен на ${percent.toFixed(0)}%`,
      });
    } else {
      insights.push({
        type: 'info',
        icon: '🎯',
        text: `До выполнения плана осталось ${money(profitPlan - netProfit)}`,
      });
    }
  }

  return {
    dateFrom,
    dateTo,
    selectedModel,
    model: selectedModel,

    insights,
    revenue,
    totalProfit,
    netProfit,

    myProfit,
    alexProfit,
    expenses,
    kaspiExpenses,
    optExpenses,
    commonExpenses,
    kaspiNetProfit: kaspiProfit - kaspiExpenses,
    optNetProfit: optProfit - optExpenses,
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
function fixText(value) {
  if (value === null || value === undefined) return '';

  let text = String(value);

  try {
    if (text.includes('Ð') || text.includes('Ñ') || text.includes('Â')) {
      text = Buffer.from(text, 'latin1').toString('utf8');
    }
  } catch (e) {}

  return text;
}

app.post('/invoice-pdf', (req, res) => {
  try {
    const { items, client, channel } = req.body;

    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'Нет товаров для накладной' });
    }

    const doc = new PDFDocument({ margin: 40, size: 'A4' });
    const fontPath = path.join(__dirname, 'fonts', 'DejaVuSans.ttf');

    doc.registerFont('DejaVu', fontPath);
    doc.font('DejaVu');
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', 'attachment; filename=invoice.pdf');

    doc.pipe(res);
    doc.info.Title = 'Накладная';
    doc.info.Author = 'TechnoOpt';
    doc.fontSize(22).text('TechnoOpt', { align: 'center' });
    doc.moveDown(0.3);
    doc.fontSize(18).text('Накладная', {
      align: 'center',
    });

    doc.moveDown();
    doc.fontSize(11).text(`Дата: ${todayRu()}`);
    doc.text(fixText(`Клиент: ${client || '-'}`));
    doc.text(fixText(`Канал: ${channel || '-'}`));

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
  const doc = new PDFDocument({
    margin: 36,
    size: 'A4',
  });

  const fontPath = path.join(__dirname, 'fonts', 'DejaVuSans.ttf');

  if (fs.existsSync(fontPath)) {
    doc.registerFont('DejaVu', fontPath);
    doc.font('DejaVu');
  }

  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename=${filename}`);

  doc.pipe(res);
  return doc;
}

const PDF = {
  left: 36,
  right: 559,
  width: 523,
  blue: '#2563EB',
  dark: '#111827',
  gray: '#6B7280',
  light: '#F3F4F6',
  line: '#D1D5DB',
};

function drawTop(doc, title, subtitle = '') {
  doc.rect(0, 0, 595, 92).fill(PDF.blue);

  doc
    .fillColor('white')
    .fontSize(24)
    .text('TechnoOpt', PDF.left, 24);

  doc
    .fontSize(14)
    .text(title, PDF.left, 56);

  if (subtitle) {
    doc
      .fillColor(PDF.gray)
      .fontSize(9)
      .text(subtitle, PDF.left, 108);
    return 132;
  }

  return 118;
}

function drawCard(doc, x, y, w, title, value) {
  doc.roundedRect(x, y, w, 56, 10).fill(PDF.light);

  doc
    .fillColor(PDF.gray)
    .fontSize(8.5)
    .text(title, x + 10, y + 9, { width: w - 20 });

  doc
    .fillColor(PDF.dark)
    .fontSize(11)
    .text(value, x + 10, y + 30, { width: w - 20 });
}

function ensurePage(doc, y, minSpace = 70) {
  if (y + minSpace > 780) {
    doc.addPage();
    return 40;
  }

  return y;
}

function drawSectionTitle(doc, title, y) {
  y = ensurePage(doc, y, 45);

  doc
    .fillColor(PDF.dark)
    .fontSize(14)
    .text(title, PDF.left, y);

  return y + 24;
}

function drawTableHeader(doc, y, columns) {
  y = ensurePage(doc, y, 40);

  doc
    .roundedRect(PDF.left, y, PDF.width, 24, 6)
    .fill('#E5E7EB');

  doc.fillColor(PDF.dark).fontSize(8.5);

  columns.forEach((c) => {
    doc.text(c.title, c.x, y + 7, {
      width: c.w,
      align: c.align || 'left',
    });
  });

  return y + 32;
}

function drawTableRow(doc, y, columns, index) {
  const heights = columns.map((c) =>
    doc.heightOfString(String(c.value ?? ''), {
      width: c.w,
      align: c.align || 'left',
    })
  );

  const rowHeight = Math.max(22, Math.max(...heights) + 10);

  if (y + rowHeight > 770) {
    doc.addPage();
    y = 40;
  }

  if (index % 2 === 0) {
    doc.rect(PDF.left, y - 5, PDF.width, rowHeight).fill('#F9FAFB');
  }

  doc.fillColor(PDF.dark).fontSize(8.5);

  columns.forEach((c) => {
    doc.text(String(c.value ?? ''), c.x, y, {
      width: c.w,
      align: c.align || 'left',
    });
  });

  return y + rowHeight;
}

function periodText(dataOrReq) {
  const dateFrom = dataOrReq.dateFrom || dataOrReq.query?.dateFrom || '—';
  const dateTo = dataOrReq.dateTo || dataOrReq.query?.dateTo || '—';
  return `Период: ${dateFrom} - ${dateTo}`;
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

    const doc = setupPdf(res, 'expenses-report.pdf');

    let total = 0;
    let stas = 0;
    let alex = 0;
    let common = 0;

    filtered.forEach((row) => {
      const type = String(getCell(row, ['Тип', 'type'], 1)).trim();
      const amount = toNumber(getCell(row, ['Сумма', 'amount'], 2));

      total += amount;

      if (type.includes('Стас')) stas += amount;
      else if (type.includes('Алексей')) alex += amount;
      else common += amount;
    });

    let y = drawTop(doc, 'Отчёт по расходам', `Период: ${dateFrom || '—'} - ${dateTo || '—'}`);

    drawCard(doc, 36, y, 122, 'Итого', money(total));
    drawCard(doc, 169, y, 122, 'Стас', money(stas));
    drawCard(doc, 302, y, 122, 'Алексей', money(alex));
    drawCard(doc, 435, y, 122, 'Общие', money(common));

    y += 82;
    y = drawSectionTitle(doc, 'Список расходов', y);

        const header = [
          { title: 'Дата', x: 46, w: 60 },
          { title: 'Канал', x: 112, w: 70 },
          { title: 'Тип', x: 188, w: 120 },
          { title: 'Комментарий', x: 314, w: 145 },
          { title: 'Сумма', x: 462, w: 82, align: 'right' },
        ];

        y = drawTableHeader(doc, y, header);

        filtered.forEach((row, index) => {
          const rawDate = getCell(row, ['Дата', 'date'], 0);
          const channel =
            String(getCell(row, ['Канал', 'channel'], 3)).trim() || 'Общие';
          const type = String(getCell(row, ['Тип', 'type'], 1)).trim();
          const amount = toNumber(getCell(row, ['Сумма', 'amount'], 2));
          const comment =
            String(getCell(row, ['Комментарий', 'comment'], 9)).trim();

          y = drawTableRow(
            doc,
            y,
            [
              { value: rawDate, x: 46, w: 60 },
              { value: channel, x: 112, w: 70 },
              { value: type || '-', x: 188, w: 120 },
              { value: comment || '-', x: 314, w: 145 },
              { value: money(amount), x: 462, w: 82, align: 'right' },
            ],
            index
          );
        });

    y = ensurePage(doc, y, 50);
    y += 12;

    doc.moveTo(PDF.left, y).lineTo(PDF.right, y).strokeColor(PDF.line).stroke();
    y += 18;

    doc
      .fillColor(PDF.dark)
      .fontSize(16)
      .text(`ИТОГО: ${money(total)}`, PDF.left, y, {
        width: PDF.width,
        align: 'right',
      });

    doc.end();
  } catch (error) {
    console.error('Ошибка /expenses-report/pdf:', error);
    res.status(500).json({
      error: 'Ошибка PDF отчёта расходов',
      details: error.message,
    });
  }
});

// ================= ОБЩИЙ ОТЧЁТ БИЗНЕСА =================

app.get('/business-report/html', async (req, res) => {
  try {
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.send(`
<!doctype html>
<html lang="ru">
<head><meta charset="utf-8"><title>Отчёт</title></head>
<body style="font-family: Arial; padding: 20px;">
  <h1>TechnoOpt</h1>
  <h2>Общий отчёт бизнеса</h2>
  <p>Русский текст работает нормально 👍</p>
</body>
</html>
    `);
  } catch (error) {
    console.error('Ошибка /business-report/html:', error);
    res.status(500).send('Ошибка HTML отчёта');
  }
});

app.get('/business-report/pdf', async (req, res) => {
  try {
    const data = await buildAnalyticsReportData(req);
    const doc = setupPdf(res, 'business-report.pdf');

    let y = drawTop(doc, 'Общий отчёт бизнеса', periodText(data));

    drawCard(doc, 36, y, 122, 'Выручка', money(data.revenue));
    drawCard(doc, 169, y, 122, 'Валовая прибыль', money(data.totalProfit));
    drawCard(doc, 302, y, 122, 'Расходы', money(data.expenses));
    drawCard(doc, 435, y, 122, 'Чистая прибыль', money(data.netProfit));

    y += 82;

    drawCard(doc, 36, y, 122, 'Стас', money(data.myNet));
    drawCard(doc, 169, y, 122, 'Алексей', money(data.alexNet));
    drawCard(doc, 302, y, 122, 'Продаж', String(data.salesCount));
    drawCard(doc, 435, y, 122, 'Маржинальность', `${Number(data.margin || 0).toFixed(1)}%`);

    y += 86;

    y = drawSectionTitle(doc, 'Каналы продаж', y);

    y = drawTableHeader(doc, y, [
      { title: 'Канал', x: 46, w: 100 },
      { title: 'Выручка', x: 180, w: 110, align: 'right' },
      { title: 'Прибыль', x: 320, w: 110, align: 'right' },
      { title: 'Продаж', x: 470, w: 70, align: 'right' },
    ]);

    const channels = [
      {
        name: 'Каспий',
        revenue: data.kaspiRevenue,
        profit: data.kaspiProfit,
        count: data.kaspiCount,
      },
      {
        name: 'ОПТ',
        revenue: data.optRevenue,
        profit: data.optProfit,
        count: data.optCount,
      },
    ];

    channels.forEach((item, index) => {
      y = drawTableRow(
        doc,
        y,
        [
          { value: item.name, x: 46, w: 100 },
          { value: money(item.revenue), x: 180, w: 110, align: 'right' },
          { value: money(item.profit), x: 320, w: 110, align: 'right' },
          { value: item.count, x: 470, w: 70, align: 'right' },
        ],
        index
      );
    });

    y += 20;
    y = drawSectionTitle(doc, 'Расходы по каналам', y);

    y = drawTableHeader(doc, y, [
      { title: 'Канал', x: 46, w: 100 },
      { title: 'Прибыль до расходов', x: 170, w: 120, align: 'right' },
      { title: 'Расходы', x: 310, w: 100, align: 'right' },
      { title: 'Чистая прибыль', x: 430, w: 115, align: 'right' },
    ]);

    const expenseChannels = [
      {
        name: 'Каспий',
        profit: data.kaspiProfit || 0,
        expenses: data.kaspiExpenses || 0,
        net: data.kaspiNetProfit || 0,
      },
      {
        name: 'ОПТ',
        profit: data.optProfit || 0,
        expenses: data.optExpenses || 0,
        net: data.optNetProfit || 0,
      },
      {
        name: 'Общие',
        profit: 0,
        expenses: data.commonExpenses || 0,
        net: -(data.commonExpenses || 0),
      },
    ];

    expenseChannels.forEach((item, index) => {
      y = drawTableRow(
        doc,
        y,
        [
          { value: item.name, x: 46, w: 100 },
          { value: money(item.profit), x: 170, w: 120, align: 'right' },
          { value: money(item.expenses), x: 310, w: 100, align: 'right' },
          { value: money(item.net), x: 430, w: 115, align: 'right' },
        ],
        index
      );
    });

    y += 20;
    y = drawSectionTitle(doc, 'Доп. доходы 50/50', y);

    drawCard(doc, 36, y, 122, 'Доход', money(data.sideIncomeTotal || 0));
    drawCard(doc, 169, y, 122, 'Расход', money(data.sideIncomeExpense || 0));
    drawCard(doc, 302, y, 122, 'Чистая прибыль', money(data.sideIncomeProfit || 0));
    drawCard(doc, 435, y, 122, 'Итого общий', money(data.totalNetWithSideIncome || 0));

    y += 82;

    drawCard(doc, 36, y, 255, 'Стас итог с доп. доходами', money(data.myNetWithSideIncome || data.myNet || 0));
    drawCard(doc, 302, y, 255, 'Алексей итог с доп. доходами на пиво в Line Brew', money(data.alexNetWithSideIncome || data.alexNet || 0));

    y += 86;

    if (Array.isArray(data.sideIncomeItems) && data.sideIncomeItems.length > 0) {
      y = drawSectionTitle(doc, 'Расшифровка доп. доходов', y);

      y = drawTableHeader(doc, y, [
        { title: 'Дата', x: 46, w: 65 },
        { title: 'Тип / описание', x: 120, w: 190 },
        { title: 'Доход', x: 320, w: 70, align: 'right' },
        { title: 'Расход', x: 395, w: 70, align: 'right' },
        { title: 'Чистая', x: 470, w: 75, align: 'right' },
      ]);

      data.sideIncomeItems.forEach((item, index) => {
        y = drawTableRow(
          doc,
          y,
          [
            { value: item.date || '', x: 46, w: 65 },
            { value: `${item.type || '-'} / ${item.description || '-'}`, x: 120, w: 190 },
            { value: money(item.income), x: 320, w: 70, align: 'right' },
            { value: money(item.expense), x: 395, w: 70, align: 'right' },
            { value: money(item.profit), x: 470, w: 75, align: 'right' },
          ],
          index
        );
      });
    }

    doc.end();
  } catch (error) {
    console.error('Ошибка /business-report/pdf:', error);
    res.status(500).json({
      error: 'Ошибка PDF бизнес-отчёта',
      details: error.message,
    });
  }
});

// ================= ОТЧЁТ ПО КЛИЕНТАМ =================

app.get('/clients-report/pdf', async (req, res) => {
  try {
    const data = await buildAnalyticsReportData(req);
    const doc = setupPdf(res, 'clients-report.pdf');

    let y = drawTop(doc, 'Отчёт по клиентам', periodText(data));

    drawCard(doc, 36, y, 166, 'Выручка', money(data.revenue));
    drawCard(doc, 214, y, 166, 'Прибыль', money(data.totalProfit));
    drawCard(doc, 392, y, 166, 'Продаж', String(data.salesCount));

    y += 82;
    y = drawSectionTitle(doc, 'Клиенты', y);

    y = drawTableHeader(doc, y, [
      { title: '№', x: 46, w: 25 },
      { title: 'Клиент', x: 80, w: 190 },
      { title: 'Выручка', x: 285, w: 90, align: 'right' },
      { title: 'Прибыль', x: 390, w: 90, align: 'right' },
      { title: 'Продаж', x: 500, w: 45, align: 'right' },
    ]);

    data.clients.forEach((item, index) => {
      y = drawTableRow(
        doc,
        y,
        [
          { value: index + 1, x: 46, w: 25 },
          { value: item.client || 'Без клиента', x: 80, w: 190 },
          { value: money(item.revenue), x: 285, w: 90, align: 'right' },
          { value: money(item.profit), x: 390, w: 90, align: 'right' },
          { value: item.count, x: 500, w: 45, align: 'right' },
        ],
        index
      );
    });

    doc.end();
  } catch (error) {
    console.error('Ошибка /clients-report/pdf:', error);
    res.status(500).json({
      error: 'Ошибка PDF отчёта по клиентам',
      details: error.message,
    });
  }
});

// ================= ОТЧЁТ ПО БРЕНДАМ =================

app.get('/brands-report/pdf', async (req, res) => {
  try {
    const data = await buildAnalyticsReportData(req);
    const doc = setupPdf(res, 'brands-report.pdf');

    let y = drawTop(doc, 'Отчёт по брендам', periodText(data));

    drawCard(doc, 36, y, 166, 'Выручка', money(data.revenue));
    drawCard(doc, 214, y, 166, 'Прибыль', money(data.totalProfit));
    drawCard(doc, 392, y, 166, 'Маржинальность', `${Number(data.margin || 0).toFixed(1)}%`);

    y += 82;
    y = drawSectionTitle(doc, 'Бренды', y);

    y = drawTableHeader(doc, y, [
      { title: '№', x: 46, w: 25 },
      { title: 'Бренд', x: 80, w: 100 },
      { title: 'Выручка', x: 190, w: 85, align: 'right' },
      { title: 'Прибыль', x: 285, w: 85, align: 'right' },
      { title: 'Стас', x: 380, w: 75, align: 'right' },
      { title: 'Алексей', x: 465, w: 80, align: 'right' },
    ]);

    data.brands.forEach((item, index) => {
      y = drawTableRow(
        doc,
        y,
        [
          { value: index + 1, x: 46, w: 25 },
          { value: item.brand || 'Другое', x: 80, w: 100 },
          { value: money(item.revenue), x: 190, w: 85, align: 'right' },
          { value: money(item.profit), x: 285, w: 85, align: 'right' },
          { value: money(item.myProfit), x: 380, w: 75, align: 'right' },
          { value: money(item.alexProfit), x: 465, w: 80, align: 'right' },
        ],
        index
      );
    });

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

    const doc = setupPdf(res, 'stock-report.pdf');

    let totalQty = 0;
    let totalCost = 0;

    const items = stockRows.map((row) => {
      const name = cleanProductName(
        getCell(row, ['Наименование', 'name', 'Модель', 'model'], 0)
      );

      const qty = toNumber(getCell(row, ['Количество', 'quantity', 'qty'], 1));
      const price = findPrice(name);
      const cost = price ? toNumber(price.cost) : 0;
      const total = qty * cost;

      totalQty += qty;
      totalCost += total;

      return {
        name,
        qty,
        cost,
        total,
      };
    });

    let y = drawTop(doc, 'Отчёт по остаткам', `Дата отчёта: ${todayRu()}`);

    drawCard(doc, 36, y, 166, 'Позиций', String(stockRows.length));
    drawCard(doc, 214, y, 166, 'Всего штук', String(totalQty));
    drawCard(doc, 392, y, 166, 'Сумма склада', money(totalCost));

    y += 82;
    y = drawSectionTitle(doc, 'Остатки', y);

    y = drawTableHeader(doc, y, [
      { title: '№', x: 46, w: 25 },
      { title: 'Наименование', x: 80, w: 245 },
      { title: 'Кол-во', x: 335, w: 55, align: 'right' },
      { title: 'Себ.', x: 400, w: 65, align: 'right' },
      { title: 'Итого', x: 475, w: 70, align: 'right' },
    ]);

    items.forEach((item, index) => {
      y = drawTableRow(
        doc,
        y,
        [
          { value: index + 1, x: 46, w: 25 },
          { value: item.name || 'Без названия', x: 80, w: 245 },
          { value: item.qty, x: 335, w: 55, align: 'right' },
          { value: money(item.cost), x: 400, w: 65, align: 'right' },
          { value: money(item.total), x: 475, w: 70, align: 'right' },
        ],
        index
      );
    });

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
  console.log(`Server started on port ${PORT}`);
});
