import { forwardRef, type SelectHTMLAttributes } from "react";

interface SelectProps extends SelectHTMLAttributes<HTMLSelectElement> {
  label?: string;
  error?: string;
}

const Select = forwardRef<HTMLSelectElement, SelectProps>(
  ({ label, error, className = "", children, ...props }, ref) => (
    <div className="w-full">
      {label && (
        <label className="block text-sm font-medium text-gray-700 mb-1">{label}</label>
      )}
      <select
        ref={ref}
        className={`w-full rounded-lg border px-3 py-2 text-sm shadow-sm bg-white transition-colors focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-primary-500 ${
          error ? "border-red-500" : "border-gray-300"
        } ${className}`}
        {...props}
      >
        {children}
      </select>
      {error && <p className="mt-1 text-xs text-red-600">{error}</p>}
    </div>
  )
);

Select.displayName = "Select";
export default Select;
