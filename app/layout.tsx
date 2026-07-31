import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL("https://sweetnapadads.com"),
  title: {
    default: "Sweet Looking Napa Dads",
    template: "%s · Sweet Looking Napa Dads",
  },
  description:
    "League headquarters, financial ledger, record book, and museum for the Sweet Looking Napa Dads fantasy football league.",
};

export const viewport: Viewport = {
  colorScheme: "light",
  themeColor: "#f2ecdf",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="h-full antialiased">
      <body className="min-h-full">{children}</body>
    </html>
  );
}
