import { type HTMLAttributes } from "react";

interface CardProps extends HTMLAttributes<HTMLDivElement> {
  padding?: boolean;
}

export default function Card({ padding = true, className = "", children, ...props }: CardProps) {
  return (
    <div
      className={`bg-white rounded-xl shadow-sm border border-gray-100 ${padding ? "p-5" : ""} ${className}`}
      {...props}
    >
      {children}
    </div>
  );
}
