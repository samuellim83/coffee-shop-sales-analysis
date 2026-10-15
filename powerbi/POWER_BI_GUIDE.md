# Power BI build guide

Build time: about 60–90 minutes. Power BI Desktop is free (Microsoft Store, Windows only).
Save the finished report as `powerbi/Coffee_Shop_Sales.pbix` before you push to GitHub.

---

## Step 1: Load the data with Power Query

You have two options. **Option A is easier** and gives the same model.

### Option A: from the CSV files (recommended)

1. **Home → Get data → Text/CSV** → pick `powerbi/data/fact_sales.csv` → **Transform Data** (not Load).
2. Repeat for `dim_date.csv`, `dim_product.csv`, `dim_store.csv`. All four queries now sit in the Power Query Editor.
3. Set the data types for each query. Click the icon to the left of each column header, or paste the M code below into **Home → Advanced Editor** (change the file path first).

**fact_sales**
```m
let
    Source   = Csv.Document(File.Contents("C:\coffee\powerbi\data\fact_sales.csv"),
                 [Delimiter=",", Encoding=65001, QuoteStyle=QuoteStyle.Csv]),
    Headers  = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),
    Typed    = Table.TransformColumnTypes(Headers, {
                 {"transaction_id",   Int64.Type},
                 {"date_key",         Int64.Type},
                 {"transaction_time", type time},
                 {"hour_of_day",      Int64.Type},
                 {"store_id",         Int64.Type},
                 {"product_id",       Int64.Type},
                 {"transaction_qty",  Int64.Type},
                 {"unit_price",       Currency.Type},
                 {"line_revenue",     Currency.Type}})
in
    Typed
```

**dim_date**
```m
let
    Source   = Csv.Document(File.Contents("C:\coffee\powerbi\data\dim_date.csv"),
                 [Delimiter=",", Encoding=65001, QuoteStyle=QuoteStyle.Csv]),
    Headers  = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),
    Typed    = Table.TransformColumnTypes(Headers, {
                 {"date_key", Int64.Type}, {"full_date", type date},
                 {"year", Int64.Type}, {"quarter", Int64.Type},
                 {"month_num", Int64.Type}, {"month_name", type text},
                 {"month_short", type text}, {"month_label", type text},
                 {"day_of_month", Int64.Type}, {"weekday_num", Int64.Type},
                 {"weekday_name", type text}, {"is_weekend", Int64.Type}})
in
    Typed
```

**dim_product** – types: `product_id` Whole Number, everything else Text.
**dim_store** – types: `store_id` Whole Number, `store_location` Text.

> If `full_date` shows errors after typing, your Windows locale is reading the date differently. Right-click the column → **Change Type → Using Locale…** → Date, English (United States).

4. **Home → Close & Apply.**

### Option B: straight from MySQL

1. Install **MySQL Connector/NET** (Power BI needs it for MySQL).
2. **Get data → MySQL database** → Server `localhost`, Database `coffee_shop`.
3. Tick `fact_sales`, `dim_date`, `dim_product`, `dim_store` → **Transform Data**, check types as above → **Close & Apply.**

---

## Step 2: Relationships (Model view)

Click the **Model view** icon (left bar). Power BI may auto-detect some links. Delete anything wrong and make sure you have exactly these three:

| From (many side)        | To (one side)            | Cardinality | Filter direction |
|-------------------------|--------------------------|-------------|------------------|
| `fact_sales[date_key]`  | `dim_date[date_key]`     | Many-to-one | Single           |
| `fact_sales[product_id]`| `dim_product[product_id]`| Many-to-one | Single           |
| `fact_sales[store_id]`  | `dim_store[store_id]`    | Many-to-one | Single           |

Drag the field from one table onto the matching field in the other to create a relationship. You should now see a star: `fact_sales` in the middle, three dimensions around it. **Take a screenshot of this view for your README** (`images/powerbi_model.png`).

### Tidy-ups (they matter)

1. **Mark the date table:** select `dim_date` → **Table tools → Mark as date table** → date column `full_date`. Time-intelligence DAX (DATEADD, DATESYTD) needs this.
2. **Sort month names properly:** select `dim_date[month_name]` → **Column tools → Sort by column → month_num**. Do the same for `month_short`.
3. **Sort weekdays:** `dim_date[weekday_name]` → Sort by column → `weekday_num`.
4. **Hide keys** from report view (right-click → Hide in report view): `fact_sales[date_key]`, `fact_sales[store_id]`, `fact_sales[product_id]`. This stops people slicing by the wrong column.
5. **Create a measures table:** Home → Enter data → name it `_Measures` → Load. Put all measures here.

---

## Step 3: DAX measures

Select `_Measures` → **New measure** → paste one at a time.

```dax
Total Sales = SUM ( fact_sales[line_revenue] )
```
```dax
Transactions = COUNTROWS ( fact_sales )
```
```dax
Units Sold = SUM ( fact_sales[transaction_qty] )
```
```dax
Avg Ticket = DIVIDE ( [Total Sales], [Transactions] )
```
*Average revenue per transaction line. The dataset has no receipt ID, so this is not a per-customer basket.*

```dax
Sales Prev Month =
CALCULATE ( [Total Sales], DATEADD ( dim_date[full_date], -1, MONTH ) )
```
```dax
MoM Growth % =
DIVIDE ( [Total Sales] - [Sales Prev Month], [Sales Prev Month] )
```
*Format as Percentage (Measure tools → %). January shows blank because there is no December.*

```dax
Running Total Sales =
CALCULATE (
    [Total Sales],
    FILTER (
        ALL ( dim_date[full_date] ),
        dim_date[full_date] <= MAX ( dim_date[full_date] )
    )
)
```
*Cumulative from the first day. `ALL` removes the current date filter, then `FILTER` keeps every date up to the one being shown.*

```dax
Sales YTD = TOTALYTD ( [Total Sales], dim_date[full_date] )
```
*The built-in shortcut. In this dataset it equals the running total because the data starts on 1 Jan.*

```dax
Sales per Trading Day =
DIVIDE ( [Total Sales], DISTINCTCOUNT ( fact_sales[date_key] ) )
```
*A fairer month comparison: February has only 28 days.*

```dax
% of Total Sales =
DIVIDE ( [Total Sales], CALCULATE ( [Total Sales], ALL ( fact_sales ) ) )
```

Format the money measures as Currency, 2 decimals.

### Check your numbers

If your report shows these, the model is right (verified against the SQL results):

| Month | Total Sales | MoM Growth % | Running Total | Avg Ticket |
|-------|------------:|-------------:|--------------:|-----------:|
| Jan   |  81,677.74  | (blank)      |  81,677.74    | 4.72 |
| Feb   |  76,145.19  | -6.8%        | 157,822.93    | 4.65 |
| Mar   |  98,834.68  | 29.8%        | 256,657.61    | 4.66 |
| Apr   | 118,941.08  | 20.3%        | 375,598.69    | 4.69 |
| May   | 156,727.76  | 31.8%        | 532,326.45    | 4.67 |
| Jun   | 166,485.88  | 6.2%         | 698,812.33    | 4.71 |
| **Total** | **698,812.33** | | | **4.69** |

Transactions = 149,116 · Units Sold = 214,470.

---

## Step 4: Build the report (3 pages)

**Page 1: Overview**
- 4 **Card** visuals: Total Sales, Transactions, Avg Ticket, MoM Growth %.
- **Line and clustered column chart**: X = `dim_date[month_short]`, columns = Total Sales, line = Running Total Sales.
- **Clustered bar**: Y = `dim_store[store_location]`, X = Total Sales.
- **Slicers**: `dim_store[store_location]`, `dim_date[month_name]`.

**Page 2: Products**
- **Bar chart**: Y = `dim_product[product_detail]`, X = Total Sales. Filters pane → product_detail → Filter type **Top N** → 10 by Total Sales.
- **Donut** or **Treemap**: `dim_product[product_category]` by Total Sales.
- **Matrix**: rows = category → type → detail (drill-down), values = Total Sales, Units Sold, % of Total Sales.

**Page 3: When do customers buy?**
- **Matrix heatmap**: rows = `dim_date[weekday_name]`, columns = `fact_sales[hour_of_day]`, values = Transactions. Then Format → Cell elements → **Background color** on → gradient. The morning peak lights up.
- **Column chart**: X = `fact_sales[hour_of_day]`, Y = Total Sales.
- **Column chart**: X = `dim_date[weekday_name]`, Y = Sales per Trading Day (it will look almost flat, and that flatness is the finding).

Finishing touches: one colour theme (View → Themes), a title text box on each page, consistent number formats. Then **File → Export → Export to PDF** and take screenshots of each page for `images/`.
