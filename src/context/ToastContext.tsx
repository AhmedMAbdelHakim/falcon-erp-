import React, { createContext, useContext, useState, useCallback } from 'react';
import { CheckCircle2, AlertTriangle, XCircle, X, Info as InfoIcon } from 'lucide-react';

export type ToastType = 'success' | 'error' | 'warning' | 'info';

interface Toast {
  id: string;
  message: string;
  type: ToastType;
}

interface ToastContextType {
  showToast: (message: string, type?: ToastType) => void;
}

const ToastContext = createContext<ToastContextType | undefined>(undefined);

export const ToastProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [toasts, setToasts] = useState<Toast[]>([]);

  const removeToast = useCallback((id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  const showToast = useCallback((message: string, type: ToastType = 'success') => {
    const id = Math.random().toString(36).substring(2, 9);
    setToasts((prev) => [...prev, { id, message, type }]);

    // Auto-remove after 4 seconds
    setTimeout(() => {
      removeToast(id);
    }, 4000);
  }, [removeToast]);

  return (
    <ToastContext.Provider value={{ showToast }}>
      {children}
      
      {/* Toast Portal Container */}
      <div className="fixed bottom-5 left-5 z-50 flex flex-col gap-2.5 max-w-md w-full no-print">
        {toasts.map((toast) => {
          let bg = 'bg-white text-slate-800 border-slate-200';
          let Icon = CheckCircle2;
          let iconColor = 'text-emerald-500';

          if (toast.type === 'success') {
            bg = 'bg-emerald-50 text-emerald-900 border-emerald-200';
            Icon = CheckCircle2;
            iconColor = 'text-emerald-500';
          } else if (toast.type === 'error') {
            bg = 'bg-red-50 text-red-900 border-red-200';
            Icon = XCircle;
            iconColor = 'text-red-500';
          } else if (toast.type === 'warning') {
            bg = 'bg-amber-50 text-amber-900 border-amber-200';
            Icon = AlertTriangle;
            iconColor = 'text-amber-500';
          } else if (toast.type === 'info') {
            bg = 'bg-blue-50 text-blue-900 border-blue-200';
            Icon = InfoIcon;
            iconColor = 'text-blue-500';
          }

          return (
            <div
              key={toast.id}
              className={`flex items-start gap-3 p-4 rounded-xl border shadow-lg transition-all duration-300 transform translate-y-0 animate-slide-up ${bg}`}
              style={{ direction: 'rtl' }}
            >
              <Icon className={`mt-0.5 shrink-0 ${iconColor}`} size={18} />
              <div className="flex-grow text-xs font-semibold leading-relaxed">
                {toast.message}
              </div>
              <button
                onClick={() => removeToast(toast.id)}
                className="text-slate-400 hover:text-slate-600 transition-colors p-0.5 rounded"
              >
                <X size={14} />
              </button>
            </div>
          );
        })}
      </div>
    </ToastContext.Provider>
  );
};

export const useToast = () => {
  const context = useContext(ToastContext);
  if (context === undefined) {
    throw new Error('useToast must be used within a ToastProvider');
  }
  return context;
};
