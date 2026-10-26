import { Document, Page, View, Text } from "@react-pdf/renderer";
import { styles } from "./styles";
import {
  CoverPage,
  RoomPage,
  IntegrityAppendixPage,
  SignaturePage,
} from "./condition-report";
import type { ReportPropertyInfo, ReportRoom } from "./types";

function Footer({ label }: { label: string }) {
  return (
    <View style={styles.pageFooter} fixed>
      <Text>Deposit Shield · {label}</Text>
      <Text render={({ pageNumber, totalPages }) => `Page ${pageNumber} of ${totalPages}`} />
    </View>
  );
}

export function StateDeadlinePage({
  stateName,
  deadlineDays,
  itemizedRequired,
  smallClaimsLimit,
  deadlineDateLabel,
}: {
  stateName: string;
  deadlineDays: number;
  itemizedRequired: boolean;
  smallClaimsLimit: string;
  deadlineDateLabel: string | null;
}) {
  return (
    <Page size="A4" style={styles.page}>
      <View style={styles.pageHeader}>
        <Text style={styles.h3}>{stateName} deposit return rules</Text>
        <Text style={styles.small}>Evidence packet</Text>
      </View>
      <Text style={{ marginBottom: 10, lineHeight: 1.5 }}>
        In {stateName}, landlords generally must return a tenant&apos;s security deposit within{" "}
        <Text style={{ fontFamily: "Courier" }}>{deadlineDays} days</Text> of move-out
        {deadlineDateLabel ? `, which in this case is on or before ${deadlineDateLabel}` : ""}.
      </Text>
      {itemizedRequired && (
        <Text style={{ marginBottom: 10, lineHeight: 1.5 }}>
          An itemized statement of any deductions is generally required alongside the returned portion
          of the deposit.
        </Text>
      )}
      <Text style={{ marginBottom: 10, lineHeight: 1.5 }}>
        The small-claims court limit in this state is approximately {smallClaimsLimit}, which is
        typically the venue used to recover a wrongfully withheld deposit without hiring an attorney.
      </Text>
      <View style={styles.divider} />
      <Text style={{ fontSize: 9, color: "#5b6472" }}>
        General guidance only, reviewed periodically — not legal advice. Confirm current rules with your
        state housing authority or an attorney before relying on them.
      </Text>
      <Footer label="State deadline" />
    </Page>
  );
}

export function DemandLetterPage({ letterLines }: { letterLines: string[] }) {
  return (
    <Page size="A4" style={styles.page}>
      <View style={styles.pageHeader}>
        <Text style={styles.h3}>Demand letter (draft)</Text>
        <Text style={styles.small}>Evidence packet</Text>
      </View>
      {letterLines.map((line, i) => (
        <Text key={i} style={{ marginBottom: 8, lineHeight: 1.5 }}>
          {line}
        </Text>
      ))}
      <Footer label="Demand letter" />
    </Page>
  );
}

export function SmallClaimsChecklistPage({ items }: { items: string[] }) {
  return (
    <Page size="A4" style={styles.page}>
      <View style={styles.pageHeader}>
        <Text style={styles.h3}>Small-claims checklist</Text>
        <Text style={styles.small}>Evidence packet</Text>
      </View>
      {items.map((item, i) => (
        <View key={i} style={{ flexDirection: "row", marginBottom: 8 }}>
          <Text style={{ width: 16 }}>☐</Text>
          <Text style={{ flex: 1, lineHeight: 1.4 }}>{item}</Text>
        </View>
      ))}
      <Footer label="Small-claims checklist" />
    </Page>
  );
}

export function EvidencePacketDocument({
  property,
  moveInRooms,
  moveOutRooms,
  stateName,
  deadlineDays,
  itemizedRequired,
  smallClaimsLimit,
  deadlineDateLabel,
  letterLines,
  checklistItems,
}: {
  property: ReportPropertyInfo;
  moveInRooms: ReportRoom[];
  moveOutRooms: ReportRoom[];
  stateName: string;
  deadlineDays: number;
  itemizedRequired: boolean;
  smallClaimsLimit: string;
  deadlineDateLabel: string | null;
  letterLines: string[];
  checklistItems: string[];
}) {
  return (
    <Document title={`Deposit Shield — Evidence Packet — ${property.displayName}`}>
      <CoverPage title="Evidence packet" property={property} watermark={false} />
      {moveInRooms.map((room) => (
        <RoomPage key={`in-${room.name}`} room={room} phaseLabel="Move-in" watermark={false} />
      ))}
      {moveOutRooms.map((room) => (
        <RoomPage key={`out-${room.name}`} room={room} phaseLabel="Move-out" watermark={false} />
      ))}
      <StateDeadlinePage
        stateName={stateName}
        deadlineDays={deadlineDays}
        itemizedRequired={itemizedRequired}
        smallClaimsLimit={smallClaimsLimit}
        deadlineDateLabel={deadlineDateLabel}
      />
      <DemandLetterPage letterLines={letterLines} />
      <SmallClaimsChecklistPage items={checklistItems} />
      <IntegrityAppendixPage label="Evidence packet" />
      <SignaturePage label="Evidence packet" />
    </Document>
  );
}
