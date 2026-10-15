# Insights & recommendations

**Scope:** 149,116 transaction lines · 3 outlets (Astoria, Hell's Kitchen, Lower Manhattan) · 1 Jan – 30 Jun 2023 · **$698,812 revenue**.
Every number below comes from `sql/03_analysis.sql` (full output in `results/analysis_output_full.txt`).

---

## Key findings

### 1. Revenue doubled in six months, and it came from more customers, not bigger spends
- Monthly revenue grew from **$81.7k (Jan) to $166.5k (Jun), +103.8%**.
- Transactions grew almost exactly the same, **17,314 → 35,352 (+104.2%)**.
- Average ticket stayed flat at **$4.65–$4.72** every month.
- So the growth is all footfall. The business has not yet learned to make each visit worth more.

### 2. The February "drop" is a calendar effect
- February shows -6.8% vs January, but it has 3 fewer days.
- Per trading day, February ($2,719/day) was actually **up 3.2%** on January ($2,635/day).
- From then on, daily revenue climbs every month, reaching **$5,550/day in June**.

### 3. The morning rush is the business
- **7–10am brings in 45.8% of revenue**, and 8–10am alone 36.7%.
- **10am is the peak hour at all three outlets.**
- After 11am revenue drops to roughly half the peak and stays flat until about 5pm.

### 4. Day of the week barely matters
- Average daily revenue ranges from $3,782 (Sunday) to $3,911 (Monday), a spread of only **3.4%**.
- Weekends are not busier than weekdays. Demand is driven by time of day, not day of week.

### 5. The three outlets perform almost identically
- Revenue share: Hell's Kitchen 33.8%, Astoria 33.2%, Lower Manhattan 32.9%.
- **Lower Manhattan has the highest ticket ($4.81, 1.50 items per transaction)**; Astoria the lowest ($4.59, 1.40).

### 6. Coffee and tea carry the menu, but revenue is spread wide
- Coffee 38.6% + Tea 28.1% = **two-thirds of revenue**. Bakery 11.8%, Drinking Chocolate 10.4%.
- The **top 2 products are both drinking chocolate** (Sustainably Grown Organic Lg, Dark chocolate Lg), each about 3% of revenue.
- It takes **43 of 80 products to reach 80% of revenue**, so there is no small set of hero products. The bottom of the list (e.g. Dark chocolate packaged at $755 for six months) is a candidate for review.

---

## Recommendations

| # | Recommendation | Based on | How to measure |
|---|---|---|---|
| 1 | **Lift the average ticket with morning bundles** (e.g. drink + pastry). Growth so far is all traffic; ticket size is the untapped lever. Illustration: +$0.25 per transaction at June's volume would be about **$8.8k extra per month**. | Finding 1, 3 | Avg Ticket, Bakery attach rate |
| 2 | **Staff and prep for 7–11am**, with the most staff around 10am. Consider mobile pre-order to move the queue faster. | Finding 3 | Transactions per hour at peak |
| 3 | **Run an afternoon offer (12–5pm)** to fill the flat post-rush period, instead of weekend promotions. | Finding 3, 4 | Afternoon revenue share |
| 4 | **Copy Lower Manhattan's upselling** to Astoria. If Astoria matched LM's $4.81 ticket on its June transactions, that is roughly +$2.6k a month (estimate). | Finding 5 | Avg Ticket by store |
| 5 | **Promote drinking chocolate and Large sizes**, already top sellers, and review the slowest products once cost data is available. | Finding 6 | Revenue by product |

---

## Limitations (be upfront about these in interviews)
- **No cost data**, so this is revenue, not profit. A low-revenue product could still be high-margin.
- **No receipt or customer ID.** Each row is one product line, so "ticket" means revenue per line, not per basket, and repeat customers cannot be tracked.
- **Only six months.** We can't tell whether the Jan→Jun growth is seasonal (warmer weather, new year) or lasting.
- The data doesn't explain *why* traffic doubled (marketing, new menu, store changes), so recommendation 1 assumes the growth continues.
