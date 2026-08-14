import * as React from 'preact/compat';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '../../lib/utils';

const buttonVariants = cva(
  'inline-flex items-center justify-center gap-2.5 tracking-tight whitespace-nowrap rounded-xl text-sm font-semibold transition-all duration-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-900 focus-visible:ring-offset-2 active:scale-[0.98] disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:size-4 [&_svg]:shrink-0 dark:focus-visible:ring-slate-100',
  {
    variants: {
      variant: {
        default: 'bg-slate-900 text-white shadow-md hover:bg-slate-800 hover:shadow-lg dark:bg-white dark:text-slate-950 dark:hover:bg-slate-100 border border-slate-950/20 dark:border-white/20',
        primary: 'bg-purple-600 text-white shadow-md hover:bg-purple-500 hover:shadow-purple-500/25 dark:bg-purple-500 dark:text-white dark:hover:bg-purple-400 border border-purple-400/30',
        destructive: 'bg-rose-600 text-white shadow-md hover:bg-rose-500 dark:bg-rose-600 dark:hover:bg-rose-500 border border-rose-500/30',
        outline: 'border-2 border-slate-300 dark:border-slate-700 bg-white/80 dark:bg-slate-900/80 text-slate-800 dark:text-slate-200 hover:border-slate-400 dark:hover:border-slate-500 hover:bg-slate-100 dark:hover:bg-slate-800 shadow-sm',
        secondary: 'bg-slate-200/80 dark:bg-slate-800/90 text-slate-900 dark:text-slate-100 hover:bg-slate-300/80 dark:hover:bg-slate-700/90 border border-slate-300/50 dark:border-slate-700/50 shadow-sm',
        ghost: 'hover:bg-slate-200/60 dark:hover:bg-slate-800/60 text-slate-700 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white',
        link: 'text-slate-900 dark:text-slate-100 underline-offset-4 hover:underline font-bold',
      },
      size: {
        default: 'h-10 px-5 py-2.5',
        sm: 'h-8.5 rounded-lg px-3.5 text-xs',
        lg: 'h-12 rounded-xl px-7 text-base font-bold',
        icon: 'h-10 w-10 rounded-xl',
      },
    },
    defaultVariants: {
      variant: 'default',
      size: 'default',
    },
  }
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean;
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    return (
      <button
        className={cn(buttonVariants({ variant, size, className }))}
        ref={ref}
        {...props}
      />
    );
  }
);
Button.displayName = 'Button';

export { Button, buttonVariants };
