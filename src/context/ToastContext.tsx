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
          let Icon = CheckCircle2;
          const style = {
            backgroundColor: '#fff8ec',
            color: '#17110e',
            borderColor: '#d7bea0',
            direction: 'rtl' as const,
          };
          const iconStyle = { color: '#7a1621' };

          if (toast.type === 'success') {
            Icon = CheckCircle2;
          } else if (toast.type === 'error') {
            Icon = XCircle;
          } else if (toast.type === 'warning') {
            Icon = AlertTriangle;
          } else if (toast.type === 'info') {
            Icon = InfoIcon;
          }

          return (
            <div
              key={toast.id}
              className="flex items-start gap-3 p-4 rounded border shadow-lg transition-all duration-300 transform translate-y-0 animate-slide-up"
              style={style}
            >
              <Icon className="mt-0.5 shrink-0" style={iconStyle} size={18} />
              <div className="flex-grow text-xs font-semibold leading-relaxed">
                {toast.message}
              </div>
              <button
                onClick={() => removeToast(toast.id)}
                className="transition-colors p-0.5 rounded"
                style={{ color: '#7a1621' }}
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
