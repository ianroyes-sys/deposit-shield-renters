export interface ReportPhoto {
  url: string;
  capturedAt: string;
  condition: "good" | "fair" | "damaged";
  note: string | null;
  sha256: string;
}

export interface ReportRoom {
  name: string;
  photos: ReportPhoto[];
}

export interface ReportPropertyInfo {
  displayName: string;
  addressLines: string[];
  tenantEmail: string;
  depositAmountLabel: string;
  dateLabel: string;
  stateName?: string;
  stateDeadlineDays?: number;
}
