export type TeamFinancialBalanceRecord = {
  season_team_id: string;
  team_obligations_cents: number;
  payments_from_team_cents: number;
  league_obligations_cents: number;
  payments_to_team_cents: number;
  balance_increases_cents: number;
  balance_decreases_cents: number;
  balance_cents: number;
};

export type FinanceTeamLabel = {
  id: string;
  name: string;
  abbreviation: string | null;
};

export type TeamBalanceRow = TeamFinancialBalanceRecord & {
  team_name: string;
  abbreviation: string | null;
  status: "owes_league" | "league_owes_team" | "settled";
};

export type ObligationEventRecord = {
  id: string;
  season_team_id: string;
  direction: "team_owes_league" | "league_owes_team";
  amount_cents: number;
  category: string;
  description: string;
  occurred_on: string;
};

export type ObligationReconciliationRecord = {
  obligation_id: string;
  allocated_cents: number;
  outstanding_cents: number;
  reconciliation_status: "open" | "partial" | "settled";
};

export type PaymentEventRecord = {
  id: string;
  season_team_id: string;
  direction: "from_team" | "to_team";
  amount_cents: number;
  paid_on: string;
  method: string | null;
  note: string | null;
};

export type PaymentReconciliationRecord = {
  payment_id: string;
  allocated_cents: number;
  unallocated_cents: number;
  reconciliation_status: "unallocated" | "partial" | "allocated";
};

export type AdjustmentEventRecord = {
  id: string;
  season_team_id: string;
  direction: "increase_team_balance" | "decrease_team_balance";
  amount_cents: number;
  reason: string;
  occurred_on: string;
};

export type TeamLedgerEntry = {
  id: string;
  kind: "obligation" | "payment" | "adjustment";
  occurred_on: string;
  title: string;
  detail: string;
  direction:
    | ObligationEventRecord["direction"]
    | PaymentEventRecord["direction"]
    | AdjustmentEventRecord["direction"];
  amount_cents: number;
  reconciliation_status: string | null;
  remainder_cents: number | null;
};

export function buildTeamBalanceRows(
  balances: TeamFinancialBalanceRecord[],
  teams: FinanceTeamLabel[],
): TeamBalanceRow[] {
  const labels = new Map(teams.map((team) => [team.id, team]));

  return balances
    .map((balance) => {
      const team = labels.get(balance.season_team_id);
      return {
        ...balance,
        team_name: team?.name ?? "League team",
        abbreviation: team?.abbreviation ?? null,
        status: balance.balance_cents > 0
          ? "owes_league" as const
          : balance.balance_cents < 0
            ? "league_owes_team" as const
            : "settled" as const,
      };
    })
    .sort((left, right) =>
      right.balance_cents - left.balance_cents
      || left.team_name.localeCompare(right.team_name),
    );
}

export function summarizeTeamBalances(rows: TeamBalanceRow[]) {
  return rows.reduce(
    (summary, row) => {
      if (row.balance_cents > 0) summary.teams_owe_cents += row.balance_cents;
      if (row.balance_cents < 0) summary.league_owes_cents += Math.abs(row.balance_cents);
      if (row.balance_cents === 0) summary.settled_teams += 1;
      return summary;
    },
    { teams_owe_cents: 0, league_owes_cents: 0, settled_teams: 0 },
  );
}

export function buildTeamLedger(
  seasonTeamId: string,
  obligations: ObligationEventRecord[],
  obligationReconciliation: ObligationReconciliationRecord[],
  payments: PaymentEventRecord[],
  paymentReconciliation: PaymentReconciliationRecord[],
  adjustments: AdjustmentEventRecord[],
): TeamLedgerEntry[] {
  const obligationState = new Map(
    obligationReconciliation.map((item) => [item.obligation_id, item]),
  );
  const paymentState = new Map(
    paymentReconciliation.map((item) => [item.payment_id, item]),
  );

  const entries: TeamLedgerEntry[] = [
    ...obligations
      .filter((item) => item.season_team_id === seasonTeamId)
      .map((item) => {
        const state = obligationState.get(item.id);
        return {
          id: item.id,
          kind: "obligation" as const,
          occurred_on: item.occurred_on,
          title: item.description,
          detail: item.category.replaceAll("_", " "),
          direction: item.direction,
          amount_cents: item.amount_cents,
          reconciliation_status: state?.reconciliation_status ?? null,
          remainder_cents: state?.outstanding_cents ?? null,
        };
      }),
    ...payments
      .filter((item) => item.season_team_id === seasonTeamId)
      .map((item) => {
        const state = paymentState.get(item.id);
        return {
          id: item.id,
          kind: "payment" as const,
          occurred_on: item.paid_on,
          title: item.direction === "from_team" ? "Payment received" : "Payment sent",
          detail: item.note ?? item.method?.replaceAll("_", " ") ?? "Recorded payment",
          direction: item.direction,
          amount_cents: item.amount_cents,
          reconciliation_status: state?.reconciliation_status ?? null,
          remainder_cents: state?.unallocated_cents ?? null,
        };
      }),
    ...adjustments
      .filter((item) => item.season_team_id === seasonTeamId)
      .map((item) => ({
        id: item.id,
        kind: "adjustment" as const,
        occurred_on: item.occurred_on,
        title: "Audited adjustment",
        detail: item.reason,
        direction: item.direction,
        amount_cents: item.amount_cents,
        reconciliation_status: null,
        remainder_cents: null,
      })),
  ];

  return entries.sort((left, right) =>
    right.occurred_on.localeCompare(left.occurred_on)
    || left.kind.localeCompare(right.kind)
    || left.id.localeCompare(right.id),
  );
}
