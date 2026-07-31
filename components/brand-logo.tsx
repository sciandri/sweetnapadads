import Image from "next/image";

import logo from "@/logo/sweetlookingnapadads.png";

type BrandLogoProps = {
  alt?: string;
  className?: string;
  priority?: boolean;
  sizes?: string;
};

export function BrandLogo({
  alt = "Sweet Looking Napa Dads Fantasy Football",
  className,
  priority = false,
  sizes = "160px",
}: BrandLogoProps) {
  return (
    <Image
      alt={alt}
      className={className}
      placeholder="empty"
      priority={priority}
      sizes={sizes}
      src={logo}
    />
  );
}
