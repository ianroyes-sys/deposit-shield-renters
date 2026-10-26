import { StyleSheet } from "@react-pdf/renderer";

// Uses react-pdf's built-in standard fonts (Times-Roman / Helvetica / Courier)
// so PDF generation never depends on fetching external font files — keeps
// this fully offline-capable ("zero external API").
export const INK = "#0b1220";
export const BRASS = "#b08d4c";
export const EMERALD = "#0e9f6e";
export const CLAY = "#c4553b";
export const PAPER = "#faf7f2";

export const styles = StyleSheet.create({
  page: {
    fontFamily: "Helvetica",
    fontSize: 10,
    color: INK,
    backgroundColor: "#ffffff",
    padding: 40,
  },
  coverPage: {
    fontFamily: "Helvetica",
    fontSize: 10,
    color: PAPER,
    backgroundColor: INK,
    padding: 48,
    justifyContent: "space-between",
  },
  serif: { fontFamily: "Times-Roman" },
  mono: { fontFamily: "Courier" },
  h1: { fontFamily: "Times-Roman", fontSize: 30, marginBottom: 6 },
  h2: { fontFamily: "Times-Roman", fontSize: 18, marginBottom: 10 },
  h3: { fontFamily: "Times-Roman", fontSize: 13, marginBottom: 6 },
  small: { fontSize: 8, color: "#5b6472" },
  brassText: { color: BRASS },
  divider: { borderBottomWidth: 1, borderBottomColor: "#d8dbe2", marginVertical: 12 },
  row: { flexDirection: "row" },
  wrap: { flexDirection: "row", flexWrap: "wrap" },
  pageHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    marginBottom: 16,
    paddingBottom: 10,
    borderBottomWidth: 1,
    borderBottomColor: "#d8dbe2",
  },
  pageFooter: {
    position: "absolute",
    bottom: 24,
    left: 40,
    right: 40,
    flexDirection: "row",
    justifyContent: "space-between",
    fontSize: 8,
    color: "#9099a6",
  },
  photoCard: {
    width: "31%",
    marginRight: "2%",
    marginBottom: 12,
    borderWidth: 1,
    borderColor: "#e4e8ee",
    borderRadius: 4,
    padding: 4,
  },
  photoImage: {
    width: "100%",
    height: 110,
    objectFit: "cover",
    borderRadius: 2,
    marginBottom: 4,
  },
  watermark: {
    position: "absolute",
    top: 320,
    left: -80,
    fontSize: 46,
    color: "#c4553b",
    opacity: 0.18,
    transform: "rotate(-30deg)",
  },
});
