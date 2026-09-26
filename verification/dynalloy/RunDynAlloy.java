import edu.mit.csail.sdg.alloy4.A4Reporter;
import edu.mit.csail.sdg.alloy4.Err;
import edu.mit.csail.sdg.alloy4.ErrorWarning;
import edu.mit.csail.sdg.alloy4.JoinableList;
import edu.mit.csail.sdg.ast.Command;
import edu.mit.csail.sdg.parser.CompModule;
import edu.mit.csail.sdg.parser.CompUtil;
import edu.mit.csail.sdg.translator.A4Options;
import edu.mit.csail.sdg.translator.A4Solution;
import edu.mit.csail.sdg.translator.TranslateAlloyToKodkod;

import java.util.ArrayList;
import java.util.List;

/**
 * Headless DynAlloy runner. SimpleCLI typechecks the program name as Alloy and
 * never calls translateCommandDynAlloy, so every .dals command fails there.
 */
public final class RunDynAlloy {
    public static void main(String[] args) throws Exception {
        if (args.length != 1) {
            System.err.println("usage: RunDynAlloy <file.dals>");
            System.exit(2);
        }
        A4Reporter reporter = new A4Reporter();
        CompModule module = CompUtil.parseEverything_fromFile(reporter, null, args[0]);
        A4Options options = new A4Options();
        options.solver = A4Options.SatSolver.SAT4J;
        options.noOverflow = true;
        int failed = 0;
        for (Command command : module.getAllCommands()) {
            System.out.println("==== " + command);
            System.out.flush();
            Command translated = command;
            if (command.isDynCommand()) {
                JoinableList<Err> errors = new JoinableList<Err>();
                List<ErrorWarning> warnings = new ArrayList<ErrorWarning>();
                translated = module.translateCommandDynAlloy(command, module, reporter, errors, warnings, options);
                for (Err error : errors) {
                    System.out.println("translation error: " + error);
                    failed++;
                }
            }
            if (failed > 0) {
                continue;
            }
            A4Solution solution = TranslateAlloyToKodkod.execute_command(
                    reporter, module.getAllReachableSigs(), translated, options);
            boolean sat = solution.satisfiable();
            if (command.check) {
                if (sat) {
                    System.out.println("COUNTEREXAMPLE");
                    System.out.println(solution);
                    failed++;
                } else {
                    System.out.println("no counterexample");
                }
            } else if (!sat) {
                System.out.println("no instance; the bound admits no trace");
                failed++;
            } else {
                System.out.println("instance found");
                System.out.println(solution);
            }
            System.out.flush();
        }
        if (failed > 0) {
            System.out.println("dynalloy: " + failed + " command(s) failed");
            System.exit(1);
        }
        System.out.println("dynalloy: every check has no counterexample and every run has an instance");
    }
}
