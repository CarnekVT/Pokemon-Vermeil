#===============================================================================
# TEMPORAL - SOLO PARA DIAGNOSTICAR EL SystemStackError.
# BORRAR ESTA CARPETA en cuanto se haya pegado el contenido de fulltrace.txt.
# Vuelca la traza COMPLETA en fulltrace.txt (raiz del juego) y detecta el
# ciclo de llamadas que se repite (la causa real del "stack level too deep").
# El errorlog.txt normal solo guarda 10 lineas (ver 004_Errors.rb:48),
# insuficientes para este tipo de error.
#===============================================================================
alias :zzz_orig_pbPrintException :pbPrintException
def pbPrintException(e)
  zzz_orig_pbPrintException(e)
  begin
    File.open("fulltrace.txt", "ab") do |f|
      f.write("\r\n=================\r\n\r\n[#{Time.now}] #{e.class}: #{e.message}\r\n")
      bt = e.backtrace || []
      f.write("Total frames: #{bt.length}\r\n")
      # Detecta el ciclo: periodo mas corto que se repite al inicio de la traza.
      cycle = nil
      limit = [bt.length / 2, 60].min
      1.upto(limit) do |p|
        ok = true
        reps = bt.length / p
        reps = 4 if reps > 4
        next if reps < 2
        1.upto(reps - 1) do |r|
          if bt[r * p, p] != bt[0, p]
            ok = false
            break
          end
        end
        if ok
          cycle = p
          break
        end
      end
      if cycle
        f.write("CICLO DETECTADO (periodo #{cycle}, aprox #{bt.length / cycle} repeticiones):\r\n")
        bt[0, cycle].each { |line| f.write("  #{line}\r\n") }
      else
        f.write("Sin ciclo simple. Primeros 150 frames:\r\n")
        bt[0, 150].each { |line| f.write("  #{line}\r\n") }
      end
    end
  rescue StandardError
  end
end
